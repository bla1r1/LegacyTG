#import "TGLoginViewControllerInternal.h"
#import "TGAlertSheet.h"
#import "TGPhoneNumberRules.h"
#import "TGAccountStore.h"
#import "TGCountryPickerViewController.h"
#import "TGLocalization.h"

@implementation TGLoginViewController (Phone)

/// The country behind the prefix, when the network's guess is wrong or the
/// number is foreign: official pushes the whole A-Z list with search.
- (void)countryPickerTapped {
    if (self.currentStep != TGLoginStepPhone)
        return;
    __weak typeof(self) weakSelf = self;
    [[TGAccountStore shared] countriesWithCompletion:^(NSArray *countries){
        TGLoginViewController *me = weakSelf;
        if (!me || me.currentStep != TGLoginStepPhone)
            return;
        if (!countries.count){
            [TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
                                  title:TGLocalized(@"Country") inView:me.view];
            return;
        }
        TGCountryPickerViewController *picker = [[TGCountryPickerViewController alloc]
                initWithCountries:countries picked:^(NSDictionary *country){
            TGLoginViewController *screen = weakSelf;
            if (!screen || screen.currentStep != TGLoginStepPhone)
                return;
            screen.phonePrefixField.text = country[@"prefix"];
            screen.savedCountryName = country[@"name"];
            [screen.countryButton setTitle:screen.savedCountryName
                                  forState:UIControlStateNormal];
            screen.prefixEdited = YES;
            [screen updateActionEnabled];
            [screen refreshPhoneNumberInfo];
            [screen.inputField becomeFirstResponder];
        }];
        [me.navigationController pushViewController:picker animated:YES];
    }];
}

- (void)inputFieldChanged:(UITextField *)sender {
    [self clearError];
    if (self.currentStep == TGLoginStepCode ||
            self.currentStep == TGLoginStepEmailCode ||
            self.currentStep == TGLoginStepRecoveryCode) {
        // The boxes paint the field's text; nothing else repaints them while
        // keys arrive, so typed digits stayed invisible.
        [self updateCodeBoxes];
        [self updateActionEnabled];
        NSString *digits = [sender.text stringByReplacingOccurrencesOfString:@"\\D"
                withString:@"" options:NSRegularExpressionSearch
                range:NSMakeRange(0, sender.text.length)];
        // Telegram submits a code as soon as it is as long as the one it sent;
        // waiting for a second tap on Done only adds a step.
        if (self.expectedCodeLength > 0 &&
                (NSInteger)digits.length == self.expectedCodeLength &&
                ![self busy])
            [self actionButtonTapped];
        return;
    }
    if (self.currentStep != TGLoginStepPhone) {
        [self updateActionEnabled];
        return;
    }
    [self updateActionEnabled];
    NSString *text = sender.text;
    if ([self looksLikeInternationalNumber:text]) {
        [self processPastedPhoneNumber:text];
        return;
    }
    [self refreshPhoneNumberInfo];
}

/// A pasted number answers its own prefix, but a national number that merely
/// begins with 1 or 7 (Germany's 171…, Russia's 7…) is not international.
/// Only a plus/00 prefix, or a 2-3 digit calling code with a plausible rest,
/// may split the field.
- (BOOL)looksLikeInternationalNumber:(NSString *)text {
    return TGPhoneNumberLooksInternational(text);
}

/// What country the prefix belongs to, and how Telegram would write the
/// number: getPhoneNumberInfo is the only thing that knows both. The answer
/// is dropped if the field moved on while it was in flight, so a slow reply
/// cannot relabel a number the user has already changed.
- (void)refreshPhoneNumberInfo {
    if (self.currentStep != TGLoginStepPhone)
        return;
    NSString *prefix = [self.phonePrefixField.text
            stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *local = [self.inputField.text
            stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (![prefix hasPrefix:@"+"])
        prefix = [@"+" stringByAppendingString:prefix ?: @""];
    if (prefix.length < 2 || local.length < 3) {
        self.countryLabel.text = nil;
        self.countryLabel.hidden = YES;
        [self layoutActiveStep];
        return;
    }

    NSString *full = [prefix stringByAppendingString:local];
    __weak typeof(self) weakSelf = self;
    [[TGAccountStore shared] phoneNumberInfoForPrefix:full completion:^(NSDictionary *info){
        TGLoginViewController *me = weakSelf;
        if (!me || me.currentStep != TGLoginStepPhone || !info)
            return;
        NSString *now = [me.phonePrefixField.text
                stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (![now hasPrefix:@"+"])
            now = [@"+" stringByAppendingString:now ?: @""];
        now = [now stringByAppendingString:me.inputField.text ?: @""];
        if (![now isEqualToString:full])
            return;
        // The country row is the one line: official does not repeat the
        // country and the formatted number under the field.
        NSString *name = info[@"name"];
        if (name.length) {
            me.savedCountryName = name;
            [me.countryButton setTitle:name forState:UIControlStateNormal];
        }
        me.countryLabel.text = nil;
        me.countryLabel.hidden = YES;
    }];
}

- (void)prefixFieldChanged:(UITextField *)sender {
    if (self.currentStep != TGLoginStepPhone) return;
    [self clearError];
    self.prefixEdited = YES;
    NSString *text = sender.text;
    if (![text hasPrefix:@"+"]) {
        text = [@"+" stringByAppendingString:[text stringByReplacingOccurrencesOfString:@"+" withString:@""]];
    }
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '+' && clean.length == 0) {
            [clean appendString:@"+"];
        } else if (c >= '0' && c <= '9') {
            [clean appendFormat:@"%C", c];
        }
    }
    sender.text = clean;
    [self updateActionEnabled];
    [self refreshPhoneNumberInfo];
}

- (void)processPastedPhoneNumber:(NSString *)raw {
    if (!raw.length) return;

    NSMutableString *cleaned = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if (c == '+' && cleaned.length == 0) {
            [cleaned appendString:@"+"];
        } else if (c >= '0' && c <= '9') {
            [cleaned appendFormat:@"%C", c];
        }
    }

    if ([cleaned hasPrefix:@"00"]) {
        [cleaned replaceCharactersInRange:NSMakeRange(0, 2) withString:@"+"];
    }

    if ([cleaned hasPrefix:@"0"] && ![cleaned hasPrefix:@"00"] && cleaned.length == 10) {
        self.inputField.text = [cleaned substringFromIndex:1];
        [self.inputField becomeFirstResponder];
        return;
    }

    NSString *digits = cleaned;
    BOOL hadPlus = [digits hasPrefix:@"+"];
    if (hadPlus) {
        digits = [digits substringFromIndex:1];
    }
    if (!digits.length) return;

    // Without + or 00 the digits are a national number; its first digits
    // say nothing about the country.
    if (!hadPlus) {
        self.inputField.text = digits;
        [self updateActionEnabled];
        [self refreshPhoneNumberInfo];
        return;
    }
    // A + typed key by key: "+9" is not yet +996, so wait for a digit past
    // the longest code before splitting.
    if (digits.length < 4)
        return;
    NSUInteger codeLength = TGPhoneCallingCodeLength(digits);
    NSString *prefix = [digits substringToIndex:codeLength];
    NSString *rest = [digits substringFromIndex:codeLength];

    self.phonePrefixField.text = [NSString stringWithFormat:@"+%@", prefix];
    self.prefixEdited = YES;
    self.inputField.text = rest;
    [self updateActionEnabled];
    [self refreshPhoneNumberInfo];
    [self.inputField becomeFirstResponder];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (self.currentStep == TGLoginStepPhone && string.length > 1) {
        NSString *existing = textField.text ?: @"";
        NSString *newText = [existing stringByReplacingCharactersInRange:range withString:string];
        [self processPastedPhoneNumber:newText];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.phonePrefixField) {
        [self.inputField becomeFirstResponder];
        return YES;
    }
    [self actionButtonTapped];
    return YES;
}

@end
