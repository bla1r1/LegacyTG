//
// TGTermsAge.h - the age check official asks before accepting terms that
// carry a minimum age (SettingsUI TermsOfServiceController: Age Verification,
// "Tap Agree to confirm that you are 16 or over.").
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// The alert text, or nil when the terms name no minimum age.
static inline NSString *TGTermsAgeConfirmation(NSInteger minAge) {
	if (minAge <= 0)
		return nil;
	return TGLocalizedFormat(@"Tap Agree to confirm that you are %@ or over.",
			[NSString stringWithFormat:@"%ld", (long)minAge]);
}
