//
//  CreditCardViewController.m
//  AuthnetLab
//
//  Created by Shankar Gosain on 07/23/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "CreditCardViewController.h"
#import "NSString+HMAC_MD5.h"

#define FLOAT_COLOR_VALUE(n) (n)/255.0

#define kCreditCardLength 16
#define kCreditCardLengthPlusSpaces (kCreditCardLength + 3)
#define kExpirationLength 4
#define kExpirationLengthPlusSlash  kExpirationLength + 1
#define kCVV2Length 4
#define kZipLength 5

#define kCreditCardObscureLength (kCreditCardLength - 4)

#define kSpace @" "
#define kSlash @"/"

#define kCardNumberErrorAlert 1001
#define kCardExpirationErrorAlert 1002

#define INFORMATION_MESSAGE @"The application utilizes the Authorize.Net SDK avaliable on GitHub under the username AurhorizeNet. Authorize.Net is a wholly owned subsidiary of Visa."
#define PAYMENT_SUCCESSFUL @"Your transaction of $20 has successfully been processed."



@interface CreditCardViewController (private)
- (void) formatValue:(UITextField *)textField;
- (BOOL) isMaxLength:(UITextField *)textField;
- (void) validateCreditCardValue;
@end

@implementation CreditCardViewController


@synthesize creditCardTextField;
@synthesize expirationTextField;
@synthesize cvv2TextField;
@synthesize zipTextField;
@synthesize swipeNowButton;
@synthesize signAuthButton;
@synthesize currentField;
@synthesize creditCardBuf;
@synthesize expirationBuf;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if([[UINavigationBar class] respondsToSelector:@selector(appearance)]) //iOS >=5.0
    {
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"header_bar.png"] forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"header_bar_landscape.png"] forBarMetrics:UIBarMetricsLandscapePhone];
        
    }

    
    [self initializeViews];
    [AuthNet authNetWithEnvironment:ENV_TEST];
    // register for keyboard notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:self.view.window];
	// register for keyboard notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:self.view.window];
    //Subscribe to this so that we can invalidate Swiper related tasks before the app goes to background state.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillGetBackGrounded) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // Do any additional setup after loading the view.
  }

-(void)viewWillAppear:(BOOL)animated{
    [self clearInputFields];
    [super viewWillAppear:YES];
    [self.keypad setCancelTransactionButton];
    
    [self.creditCardTextField becomeFirstResponder];
    
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dealloc {
    
    
	// unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillShowNotification
												  object:nil];
	// unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillHideNotification
												  object:nil];
    
    // These were registered in viewDidLoad, so remove them here
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
	
	creditCardTextField = nil;
	expirationTextField = nil;
	cvv2TextField = nil;
    zipTextField = nil;
    _keypad = nil;
}

- (void)initializeViews
{
    self.creditCardTextField.inputView = _keypad;
    self.expirationTextField.inputView = _keypad;
    self.cvv2TextField.inputView = _keypad;
    self.zipTextField.inputView = _keypad;
    
    NSString *buf = [self.creditCardTextField.text stringByReplacingOccurrencesOfString:kSpace withString:@""];
    if(buf==nil)
        buf=@"";
    self.creditCardBuf = [NSString stringWithString:buf];
    
    buf = [self.expirationTextField.text stringByReplacingOccurrencesOfString:kSlash withString:@""];
    if(buf==nil)
        buf=@"";
    self.expirationBuf = [NSString stringWithString:buf];
    
	//TODO:  REMOVE AFTER TESTING
	[self validateCreditCardValue];
}

-(void) LogoutAction{
    LogoutRequest *logoutRequest = [LogoutRequest logoutRequest];
    logoutRequest.anetApiRequest.merchantAuthentication.name = nil;
    logoutRequest.anetApiRequest.merchantAuthentication.password = nil;
    
    AuthNet *an = [AuthNet getInstance];
    [an setDelegate:self];
    [an LogoutRequest:logoutRequest];
    
     [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearInputFields
{
    self.cvv2TextField.text = @"";
    self.zipTextField.text = @"";
    self.creditCardTextField.text = @"";
    self.expirationTextField.text = @"";
    
    // Clear the buffers too
    self.creditCardBuf = @"";
    self.expirationBuf = @"";
    
    [self.creditCardTextField resignFirstResponder];
    [self.expirationTextField resignFirstResponder];
    [self.cvv2TextField resignFirstResponder];
    [self.zipTextField resignFirstResponder];
}

- (NSString*)expirationDateWithoutSeparator
{
    return [self.expirationTextField.text stringByReplacingOccurrencesOfString:kSlash withString:@""];
}

- (void) formatValue:(UITextField *)textField {
	NSMutableString *value = [NSMutableString string];
	
	if (textField == self.creditCardTextField ) {
        NSInteger length = [self.creditCardBuf length];
        
        for (int i = 0; i < length; i++) {
            
            // Reveal only the last character.
            if (length <= kCreditCardObscureLength) {
                
                if (i == (length - 1)) {
                    [value appendString:[self.creditCardBuf substringWithRange:NSMakeRange(i,1)]];
                } else {
                    [value appendString:@"●"];
                }
            }
            // Reveal the last 4 characters
            else {
                
                if (i < kCreditCardObscureLength) {
                    [value appendString:@"●"];
                } else {
                    [value appendString:[self.creditCardBuf substringWithRange:NSMakeRange(i,1)]];
                }
            }
            
            //After 4 characters add a space
            if ((i +1) % 4 == 0 &&
                ([value length] < kCreditCardLengthPlusSpaces)) {
                [value appendString:kSpace];
            }
        }
        textField.text = value;
	}
	if (textField == self.expirationTextField) {
        for (int i = 0; i < [self.expirationBuf length]; i++) {
            [value appendString:[self.expirationBuf substringWithRange:NSMakeRange(i,1)]];
            
            // After two characters append a slash.
            if ((i + 1) % 2 == 0 &&
                ([value length] < kExpirationLengthPlusSlash)) {
                [value appendString:kSlash];
            }
        }
        textField.text = value;
	}
}



- (void) validateCreditCardValue {
	NSString *ccNum = self.creditCardBuf;
	
	// Use the Authorize.Net SDK to validate credit card number
	if (![CreditCardType isValidCreditCardNumber:ccNum]) {
		self.creditCardTextField.textColor = [UIColor redColor];
	} else {
		self.creditCardTextField.textColor = [UIColor colorWithRed:FLOAT_COLOR_VALUE(98) green:FLOAT_COLOR_VALUE(169) blue:FLOAT_COLOR_VALUE(40) alpha:1];
	}
}


- (BOOL) isMaxLength:(UITextField *)textField {
    
	if (textField == self.creditCardTextField && [textField.text length] >= kCreditCardLengthPlusSpaces) {
		return YES;
	}
	else if (textField == self.expirationTextField && [textField.text length] >= kExpirationLengthPlusSlash) {
		return YES;
	}
	else if (textField == self.cvv2TextField && [textField.text length] >= kCVV2Length) {
		return YES;
	}
	else if (textField == self.zipTextField && [textField.text length] >= kZipLength) {
		return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark DecimalKeypadViewDelegate
- (void)keypad:(DecimalKeypadView *)keypad keyPressed:(NSString *)string {
    
    if ([string isEqualToString:@"⌫"]) {
        string = @"";
    }
    
    if ([string isEqualToString:@"Cancel Transaction"]) {
        return;
    }
   // [self.view textField:[self.view currentField] shouldChangeCharactersInRange:NSMakeRange(0, 0) replacementString:string];
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL) textFieldShouldBeginEditing:(UITextField *)textField {
    self.currentField = textField;
	return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	return YES;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    if (textField == self.creditCardTextField) {
        if ([string length] > 0) { //NOT A BACK SPACE Add it
            
            if ([self isMaxLength:textField])
                return NO;
            
            self.creditCardBuf  = [NSString stringWithFormat:@"%@%@", self.creditCardBuf, string];
        } else {
            
            //Back Space do manual backspace
            if ([self.creditCardBuf length] > 1) {
                self.creditCardBuf = [self.creditCardBuf substringWithRange:NSMakeRange(0, [self.creditCardBuf length] - 1)];
            } else {
                self.creditCardBuf = @"";
            }
        }
        [self formatValue:textField];
        [self validateCreditCardValue];
    } else if (textField == self.expirationTextField) {
        if ([string length] > 0) { //NOT A BACK SPACE Add it
            
            if ([self isMaxLength:textField])
                return NO;
            
            self.expirationBuf  = [NSString stringWithFormat:@"%@%@", self.expirationBuf, string];
        } else {
            
            //Back Space do manual backspace
            if ([self.expirationBuf length] > 1) {
                self.expirationBuf = [self.expirationBuf substringWithRange:NSMakeRange(0, [self.expirationBuf length] - 1)];
                [self formatValue:textField];
            } else {
                self.expirationBuf = @"";
            }
        }
        
        [self formatValue:textField];
        
    } else if (textField == self.cvv2TextField) {
        if ([string length] > 0) {
            
            if ([self isMaxLength:textField])
                return NO;
            
            self.cvv2TextField.text = [NSString stringWithFormat:@"%@%@", self.cvv2TextField.text, string];
        }else {
            
            //Back Space do manual backspace
            if ([self.cvv2TextField.text length] > 1) {
                self.cvv2TextField.text = [self.cvv2TextField.text substringWithRange:NSMakeRange(0, [self.cvv2TextField.text length] - 1)];
            } else {
                self.cvv2TextField.text = @"";
            }
        }
    } else if (textField == self.zipTextField) {
        if ([string length] > 0) {
            
            if ([self isMaxLength:textField])
                return NO;
            
            self.zipTextField.text = [NSString stringWithFormat:@"%@%@", self.zipTextField.text, string];
        }else {
            
            //Back Space do manual backspace
            if ([self.zipTextField.text length] > 1) {
                self.zipTextField.text = [self.zipTextField.text substringWithRange:NSMakeRange(0, [self.zipTextField.text length] - 1)];
            } else {
                self.zipTextField.text = @"";
            }
        }
    }
    return NO;
}


- (BOOL)textFieldShouldClear:(UITextField *)textField {
    if (textField == self.creditCardTextField) {
        self.creditCardBuf = [NSString string];
    }
    
    if (textField == self.expirationTextField) {
        self.expirationBuf = [NSString string];
    }
    return YES;
}

#pragma mark -
#pragma mark Private Method

- (void) saveCreditCardInfo {
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:_activityIndicator];
    _activityIndicator.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    [_activityIndicator startAnimating];
    
    
	AuthNet *an = [AuthNet getInstance];
    
    [an setDelegate:self];
    
    CreditCardType *c = [CreditCardType creditCardType];
	c.cardNumber = self.creditCardBuf;
	c.expirationDate = [self.expirationTextField.text stringByReplacingOccurrencesOfString:kSlash withString:@""];
	if ([self.cvv2TextField.text length]) {
		c.cardCode = [NSString stringWithString:self.cvv2TextField.text];
	}
    CustomerAddressType *b = [CustomerAddressType customerAddressType];
    
    if ([self.zipTextField.text length]) {
		b.zip = [NSString stringWithString:self.zipTextField.text];
	}
    
    PaymentType *paymentType = [PaymentType paymentType];
    paymentType.creditCard = c;
    
    ExtendedAmountType *extendedAmountTypeTax = [ExtendedAmountType extendedAmountType];
    extendedAmountTypeTax.amount = @"0";
    extendedAmountTypeTax.name = @"Tax";
    
    ExtendedAmountType *extendedAmountTypeShipping = [ExtendedAmountType extendedAmountType];
    extendedAmountTypeShipping.amount = @"0";
    extendedAmountTypeShipping.name = @"Shipping";
    
    LineItemType *lineItem = [LineItemType lineItem];
    lineItem.itemName = @"Soda";
    lineItem.itemDescription = @"Soda";
    lineItem.itemQuantity = @"1";
    lineItem.itemPrice = @"1.00";
    lineItem.itemID = @"1";
    
    TransactionRequestType *requestType = [TransactionRequestType transactionRequest];
    requestType.lineItems = [NSMutableArray arrayWithObject:lineItem];
    requestType.amount = @"20.00";
    requestType.payment = paymentType;
    requestType.tax = extendedAmountTypeTax;
    requestType.shipping = extendedAmountTypeShipping;
    
    CreateTransactionRequest *request = [CreateTransactionRequest createTransactionRequest];
    request.transactionRequest = requestType;
    request.anetApiRequest.merchantAuthentication.mobileDeviceId = @"358347040811237";
    request.anetApiRequest.merchantAuthentication.sessionToken = _sessionToken;
    
    [an purchaseWithRequest:request];
		
}


- (void) keyboardWillShow:(NSNotification *)n {
    //    [UIView setAnimationsEnabled:NO];
}

- (void) keyboardWillHide:(NSNotification *)n {
    //	[UIView setAnimationsEnabled:YES];
}


#pragma mark -
#pragma mark - AuthNetDelegate Methods

- (void)paymentSucceeded:(CreateTransactionResponse*)response {
    [self clearInputFields];
    [_activityIndicator stopAnimating];
    
    NSLog(@"Payment Success ********************** ");
    
    UIAlertView *PaumentSuccess = [[UIAlertView alloc] initWithTitle:@"Successfull Transaction" message:PAYMENT_SUCCESSFUL delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"LOGOUT",nil];
    [PaumentSuccess show];
}

- (void)paymentCanceled {
    
    NSLog(@"Payment Canceled ********************** ");
    
     [_activityIndicator stopAnimating];
    [self.navigationController popViewControllerAnimated:YES];
}

-(void) requestFailed:(AuthNetResponse *)response {
    
    NSLog(@"Payment Canceled ********************** ");
    
     [_activityIndicator stopAnimating];
    
    Messages *ma = response.anetApiResponse.messages;
    AuthNetMessage *m = [ma.messageArray objectAtIndex:0];
    
    // Since submitting same transaction with same data, showing user the alert msg.
    if ([m.code isEqualToString:@"E00027"]) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"A duplicate transaction has been submitted. Login back into the app to see the successful transaction.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    else if ([m.code isEqualToString:@"E00007"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"Your session has timed out. Please log in again.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    
}

- (void) connectionFailed:(AuthNetResponse *)response {
    NSLog(@"%@", response.responseReasonText);
    NSLog(@"Connection Failed");
    
    NSString *title = nil;
    NSString *message = nil;
    
    if ([response errorType] == NO_CONNECTION_ERROR) {
        title = NSLocalizedString(@"No Signal", @"");
        message = NSLocalizedString(@"Unable to complete your request. No Internet connection.", @"");
    } else {
        title = NSLocalizedString(@"Connection Error", @"");
        message = NSLocalizedString(@"A connection error occurred.  Please try again.", @"");
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles:nil];
    alert.delegate = self;
    [alert show];

}


-(void)logoutSucceeded:(LogoutResponse *)response{
    
    NSLog(@"Logout Success ********************** ");
   
}


#pragma mark -
#pragma mark UIAlertView Delegate

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 1){
        [self LogoutAction];
    }
}

#pragma mark -
#pragma mark IBAction

- (IBAction)onClickBarItemInfo:(id)sender {
    
    UIAlertView *infoAlertView = [[UIAlertView alloc] initWithTitle:@"Developer Information" message:INFORMATION_MESSAGE delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [infoAlertView show];
}

- (IBAction)payNowPressed:(id)sender
{
  [self createTransaction:arc4random() % 100];
}


- (IBAction)onClickLogoutPressed:(id)sender {
    [self LogoutAction];
}

- (IBAction) infoPressed {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:NSLocalizedString(@"The security code (CVV2) is a unique three or four-digit number on the back of a card (on the front for American Express).", @"")
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles:nil];
    [alert show];
    
    return;
}

- (IBAction) continuePressed {
    if (![self.creditCardBuf length]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedString(@"A card number is required to continue.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert setTag:kCardNumberErrorAlert];
        [alert show];
        
        return;
    }
    
    
    if (![CreditCardType isValidCreditCardNumber:self.creditCardBuf]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedString(@"Please enter a valid card number.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert setTag:kCardNumberErrorAlert];
        [alert show];
        
        return;
    }
    
    if (![self.expirationTextField.text length]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedString(@"An expiration date is required to continue.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert setTag:kCardExpirationErrorAlert];
        [alert show];
        
        return;
    }
    
    if ([self.expirationBuf length] != EXPIRATION_DATE_LENGTH) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedString(@"Please enter a valid expiration date.", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert setTag:kCardExpirationErrorAlert];
        [alert show];
        
        return;
    } else {
        // Validate
        NSArray *components = [[self.expirationTextField text] componentsSeparatedByString:@"/"];
        NSString *month = [components objectAtIndex:0];
        NSString *year = [components objectAtIndex:1];
        
        // Check to see if month is correct
        if ([month intValue] == 0 || [month intValue] > 12) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:NSLocalizedString(@"Please enter a valid expiration date.", @"")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil];
            [alert setTag:kCardExpirationErrorAlert];
            [alert show];
            
            return;
        }
        
        // Convert string to date object
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        NSDate *currentDate = [NSDate date];
        
        // Convert date object to desired output format
        [dateFormat setDateFormat:@"M/yyyy"];
        NSString *currentDateString = [dateFormat stringFromDate:currentDate];
        components = [currentDateString componentsSeparatedByString:@"/"];
        NSString *currentMonth = [components objectAtIndex:0];
        NSString *currentYear = [[components objectAtIndex:1] substringFromIndex:2];
        
        
        
        // Check if we are correct
        if ([year intValue] == [currentYear intValue]) {
            if ([month intValue] < [currentMonth intValue]) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                message:NSLocalizedString(@"Please enter a valid expiration date.", @"")
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                      otherButtonTitles:nil];
                [alert setTag:kCardExpirationErrorAlert];
                [alert show];
                
                return;
            }
        } else if ([year intValue] < [currentYear intValue]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:NSLocalizedString(@"Please enter a valid expiration date.", @"")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil];
            [alert setTag:kCardExpirationErrorAlert];
            [alert show];
            
            return;
        }
    }
    
    [self saveCreditCardInfo];
    
}

- (IBAction)swipePressed
{
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:_activityIndicator];
    _activityIndicator.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    [_activityIndicator startAnimating];
    
    AuthNet *an = [AuthNet getInstance];
    [an setDelegate:self];

    SwiperDataType *st = [SwiperDataType swiperDataType];
    st.encryptedValue = @"02f700801f4725008383252a343736312a2a2a2a2a2a2a2a303031305e56495341204143515549524552205445535420434152442030355e313531322a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a3f2a3b343736312a2a2a2a2a2a2a2a303031303d313531322a2a2a2a2a2a2a2a2a2a2a2a2a3f2aef80a083368880ae9515cdef8bb2ac7991d781a76f02939576605a6709762b6972b2be3a5b744f7dacffe1b276c18ba266040e749f717e2e80fdbe60164200fb056bcee846947adc9a7dd10c0a81be0c90b2674a61bbb6d3f3167170c97ed30ead1215ea1636fb8fd1e2e7e594c44aa95431323438303237373162994901000003e00181394903";
    st.deviceDescription = @"4649443d4944544543482e556e694d61672e416e64726f69642e53646b7631";
    st.encryptionType = @"TDES";
    
    PaymentType *paymentType = [PaymentType paymentType];
    paymentType.swiperData = st;
    
    TransRetailInfoType *retailInfo = [TransRetailInfoType transRetailInfoType];
    retailInfo.marketType = @"2";
    retailInfo.deviceType = @"7";
    
    ExtendedAmountType *extendedAmountTypeTax = [ExtendedAmountType extendedAmountType];
    extendedAmountTypeTax.amount = @"0";
    extendedAmountTypeTax.name = @"Tax";
    
    ExtendedAmountType *extendedAmountTypeShipping = [ExtendedAmountType extendedAmountType];
    extendedAmountTypeShipping.amount = @"0";
    extendedAmountTypeShipping.name = @"Shipping";
    
    LineItemType *lineItem = [LineItemType lineItem];
    lineItem.itemName = @"Soda";
    lineItem.itemDescription = @"Soda";
    lineItem.itemQuantity = @"1";
    lineItem.itemPrice = @"1.00";
    lineItem.itemID = @"1";
    
    TransactionRequestType *requestType = [TransactionRequestType transactionRequest];
    requestType.lineItems = [NSMutableArray arrayWithObject:lineItem];
    requestType.amount = @"20.00";
    requestType.tax = extendedAmountTypeTax;
    requestType.payment = paymentType;
    requestType.shipping = extendedAmountTypeShipping;
    requestType.retail = retailInfo;
    
    
    CreateTransactionRequest *request = [CreateTransactionRequest createTransactionRequest];
    request.transactionRequest = requestType;
    request.anetApiRequest.merchantAuthentication.mobileDeviceId = @"358347040811237";
    request.anetApiRequest.merchantAuthentication.sessionToken = _sessionToken;
    
    [an purchaseWithRequest:request];
}

-(void) _applicationWillGetBackGrounded
{
}

-(void) _applicationWillEnterForeground
{
}

/*
 Example Fingerprint Input Field Order
 "authnettest^789^67897654^10.50^"
 
 ----------WARNING!----------------
 Finger print generation requires the transaction key. This should
 be done at the server. It is shown here only for Demo purposes.
 http://www.authorize.net/support/DirectPost_guide.pdf p22-23
 */
- (NSString*)login:(NSString*)apiLoginId total:(float)amount sequence:(int)number time:(long long)nowAsLong
{
    NSString *fp = [NSString stringWithFormat:@""
                    @"%@"
                    @"^%d"
                    @"^%lld"
                    @"^%.2f"
                    @"^",
                    apiLoginId, number, nowAsLong, amount];
    return fp;
    
}


- (void) createTransaction:(float)transactionAmount
{
    float amt = transactionAmount;
    srandom(time(NULL));
    // int amount = arc4random() % 100;
    int seq = arc4random() % 100;
    
    NSDate *now = [NSDate date];
    long long nowAsLong = [now timeIntervalSince1970];
    
    
    //-------WARNING!----------------
    // Transaction key should never be stored on the device or embedded in code.
    // The usage of the transaction key below is only shown below for demo purposes.
    NSString *transactionKey           = @"4Ktq966gC55GAX7S";
    NSString *apilogind           = @"5KP3u95bQpv";

    
    NSString *fp = [self login:apilogind total:amt sequence:seq  time:nowAsLong];
    
    //-------WARNING!----------------
    // Transaction key should never be stored on the device or embedded in the code.
    // This part of the code that generates the finger print is present here only to make the sample app work.
    // Finger print generation should be done on the server.
    NSString *hexHmac = [NSString HMAC_MD5_WithTransactionKey:transactionKey fromValue:fp];
    
    NSLog(@"HMAC_MD5 in hex is %@", hexHmac);
    
    //[self createANetSOAPRequest:apilogind fp:hexHmac sequence:seq time:nowAsLong total:amount];
    [self createTransaction:apilogind fp:hexHmac sequence:seq time:nowAsLong total:amt];
    
}


- (void) createTransaction:(NSString*)apiLoginId fp:(NSString*)secret sequence:(int)number time:(long long)nowAsLong total:(float)amount {
    AuthNet *an = [AuthNet getInstance];
    [an setDelegate:self];

    
    // create the transaction.
    CreateTransactionRequest *request = [CreateTransactionRequest createTransactionRequest];
    TransactionRequestType *requestType = [TransactionRequestType transactionRequest];
    
    request.transactionRequest = requestType;
    request.transactionType = AUTH_ONLY;
    
    // set the fingerprint. Note: Finger print generation requires transaction key.
    // finger print generation must happen on the server.
    FingerPrintObjectType *fpData = [FingerPrintObjectType fingerPrintObjectType];
    fpData.hashValue = secret;
    fpData.sequenceNumber= number;
    fpData.timeStamp = nowAsLong;
    
    request.anetApiRequest.merchantAuthentication.fingerPrint = fpData;
    request.anetApiRequest.merchantAuthentication.name = apiLoginId;
    
    // set the opaque data
    OpaqueDataType *opData = [OpaqueDataType opaqueDataType];
    // sample value is set here. actual value is obtained from the LG SDK.
    opData.dataValue=[self getData2];
    opData.dataDescriptor=@"COMMON.APPLE.INAPP.PAYMENT";
    
    PaymentType *paymentType = [PaymentType paymentType];
    paymentType.creditCard= nil;
    paymentType.bankAccount= nil;
    paymentType.trackData= nil;
    paymentType.swiperData= nil;
    paymentType.opData = opData;
    
    NSString *strAmount = [NSString stringWithFormat:@"%.2f", amount];
    requestType.amount = strAmount;
    requestType.payment = paymentType;
    requestType.retail.marketType=@"0";
    requestType.retail.deviceType =@"7";
    
    OrderType *order = [OrderType order];
    order.invoiceNumber = [NSString stringWithFormat:@"%d", arc4random() % 100];
    
    // submit the transaction.
    [an purchaseWithRequest:request];
}


// note: this is a sample blob.
-(NSString* )getData2
{
    return @"eyJkYXRhIjoiUWRIZ1NMR2pOM1l5K2Y0NGVyaG15S3hJWkoxWERpVDhFdm5ya0tua3dZalhrTmdsYzVIQmNWTFBpOGdcL3pDRmN6UUxJU1lBaWNsbVwvbW9Rc3ZBV2NnQ3NlY3llVXVhb2UxZHRQRkNLR2p1a3ROOXlhZDB1a3VYNVJXcWRDbkJZa09WZ3FKRWU2U29yR2dXMlNoRmFzK21ZZWl4NFwvOVwvTGdjUkdpNHNIOHdHemZLdGJUMnFcL3ZqVzgwbldXU29LcUI0XC95NUFZalVxZmJvNmhQSW5UVUk4V2VwSTAxMG1MS294K2lLUFRucHJSaGx2Z0ZydWgzM1wvb3ZZRmFkZkVMb0wzUGVTWFRcL2dlaFwveHhTa1RDYlJKMys2WXRCU1pYMGF2UlU2eUczdWZpRUZIMXJyRkI3NXBpZVdKTnN5VzU3SlwvSENUbERvNWxXR2lWQUp4YUZocWswaGNTY2RXcDJYYkpLc0FDd3BBd2FPYitGQkJFMTZiREg5ZGlmSVRxUlVtK0llOGo1UFZ6czJBN09sWVdwdEhyMnFpR1Fjd1h1SVdPT3JBNFY1MDZlTmdEalllNThDUGVUSTdwIiwidmVyc2lvbiI6IkVDX3YxIiwiaGVhZGVyIjp7ImFwcGxpY2F0aW9uRGF0YSI6Ijk0ZWUwNTkzMzVlNTg3ZTUwMWNjNGJmOTA2MTNlMDgxNGYwMGE3YjA4YmM3YzY0OGZkODY1YTJhZjZhMjJjYzIiLCJ0cmFuc2FjdGlvbklkIjoiYzFjYWY1YWU3MmYwMDM5YTgyYmFkOTJiODI4MzYzNzM0Zjg1YmYyZjljYWRmMTkzZDFiYWQ5ZGRjYjYwYTc5NSIsImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1JSUJTekNDQVFNR0J5cUdTTTQ5QWdFd2dmY0NBUUV3TEFZSEtvWkl6ajBCQVFJaEFQXC9cL1wvXC84QUFBQUJBQUFBQUFBQUFBQUFBQUFBXC9cL1wvXC9cL1wvXC9cL1wvXC9cL1wvXC9cL1wvXC9NRnNFSVBcL1wvXC9cLzhBQUFBQkFBQUFBQUFBQUFBQUFBQUFcL1wvXC9cL1wvXC9cL1wvXC9cL1wvXC9cL1wvXC84QkNCYXhqWFlxanFUNTdQcnZWVjJtSWE4WlIwR3NNeFRzUFk3emp3K0o5SmdTd01WQU1TZE5naUc1d1NUYW1aNDRST2RKcmVCbjM2UUJFRUVheGZSOHVFc1FrZjR2T2JsWTZSQThuY0RmWUV0NnpPZzlLRTVSZGlZd3BaUDQwTGlcL2hwXC9tNDduNjBwOEQ1NFdLODR6VjJzeFhzN0x0a0JvTjc5UjlRSWhBUFwvXC9cL1wvOEFBQUFBXC9cL1wvXC9cL1wvXC9cL1wvXC8rODV2cXRweGVlaFBPNXlzTDhZeVZSQWdFQkEwSUFCTUhCdVlwU0w5S0hzU2pUM0pFQkExYVRJQWFNMDMxc2gzYzZseGRnOGNsemY2YXAzaHFVUUdRZWRkTEtLeDZURHY0UlpYcXlXQzNqTlhxVHlsb3ZlSlk9IiwicHVibGljS2V5SGFzaCI6IlwvYmI5Q05DMzZ1QmhlSEZQYm1vaEI3T28xT3NYMkora0pxdjQ4ek9WVmlRPSJ9LCJzaWduYXR1cmUiOiJNSUlEUWdZSktvWklodmNOQVFjQ29JSURNekNDQXk4Q0FRRXhDekFKQmdVckRnTUNHZ1VBTUFzR0NTcUdTSWIzRFFFSEFhQ0NBaXN3Z2dJbk1JSUJsS0FEQWdFQ0FoQmNsK1BmMytVNHBrMTNuVkQ5bndRUU1Ba0dCU3NPQXdJZEJRQXdKekVsTUNNR0ExVUVBeDRjQUdNQWFBQnRBR0VBYVFCQUFIWUFhUUJ6QUdFQUxnQmpBRzhBYlRBZUZ3MHhOREF4TURFd05qQXdNREJhRncweU5EQXhNREV3TmpBd01EQmFNQ2N4SlRBakJnTlZCQU1lSEFCakFHZ0FiUUJoQUdrQVFBQjJBR2tBY3dCaEFDNEFZd0J2QUcwd2daOHdEUVlKS29aSWh2Y05BUUVCQlFBRGdZMEFNSUdKQW9HQkFOQzgra2d0Z212V0YxT3pqZ0ROcmpURUJSdW9cLzVNS3ZsTTE0NnBBZjdHeDQxYmxFOXc0ZklYSkFEN0ZmTzdRS2pJWFlOdDM5ckx5eTd4RHdiXC81SWtaTTYwVFoyaUkxcGo1NVVjOGZkNGZ6T3BrM2Z0WmFRR1hOTFlwdEcxZDlWN0lTODJPdXA5TU1vMUJQVnJYVFBITmNzTTk5RVBVblBxZGJlR2M4N20wckFnTUJBQUdqWERCYU1GZ0dBMVVkQVFSUk1FK0FFSFpXUHJXdEpkN1laNDMxaENnN1lGU2hLVEFuTVNVd0l3WURWUVFESGh3QVl3Qm9BRzBBWVFCcEFFQUFkZ0JwQUhNQVlRQXVBR01BYndCdGdoQmNsK1BmMytVNHBrMTNuVkQ5bndRUU1Ba0dCU3NPQXdJZEJRQURnWUVBYlVLWUNrdUlLUzlRUTJtRmNNWVJFSW0ybCtYZzhcL0pYditHQlZRSmtPS29zY1k0aU5ERkFcL2JRbG9nZjlMTFU4NFRId05SbnN2VjNQcnY3UlRZODFncTBkdEM4elljQWFBa0NISUkzeXFNbko0QU91NkVPVzlrSmsyMzJnU0U3V2xDdEhiZkxTS2Z1U2dRWDhLWFFZdVpMazJScjYzTjhBcFhzWHdCTDNjSjB4Z2VBd2dkMENBUUV3T3pBbk1TVXdJd1lEVlFRREhod0FZd0JvQUcwQVlRQnBBRUFBZGdCcEFITUFZUUF1QUdNQWJ3QnRBaEJjbCtQZjMrVTRwazEzblZEOW53UVFNQWtHQlNzT0F3SWFCUUF3RFFZSktvWklodmNOQVFFQkJRQUVnWUFmSGNXWkcrZDlrSGZnb2NyaEpBalhoSUdqOHlBU1ZtdGNDWUoyMXRuek5acFhmUEk0MFwvb3BcL0FJYkpOQys4YnVzTUN5ekhzeFhKbjA3bFgrM0NiVnMzQ204OU5hZzRWXC9WYjNCcGltck9iWXNTZkQ5clhwMFFBM1VxXC93TkFxa1FyeCtmS2ZjdXAwN0drT2ljYTFJYzNpY3h0cTN6RWRLYnhPWnBvaVhZVUV3PT0ifQ==";
}


@end
