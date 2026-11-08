//
// TGPhoneNumberRules.h - the split rule for a typed phone number.
//
// A national number may itself begin with 1 (Germany's 171…) or 7 (Russia's
// 7…), so a bare leading 1 or 7 never means "international". Only a +/00
// prefix, or a known 2-3 digit calling code with a plausible rest, may move
// digits into the country-code field.
//
#ifndef TGPHONENUMBERRULES_H
#define TGPHONENUMBERRULES_H

#import <Foundation/Foundation.h>

static inline BOOL TGPhoneNumberLooksInternational(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || !text.length)
        return NO;
    if ([text hasPrefix:@"+"] || [text hasPrefix:@"00"])
        return YES;

    NSString *digits = [text stringByReplacingOccurrencesOfString:@"\\D"
            withString:@"" options:NSRegularExpressionSearch
            range:NSMakeRange(0, text.length)];
    if (digits.length < 8)
        return NO;
    // A national subscriber number, not a country code.
    if ([digits hasPrefix:@"1"] || [digits hasPrefix:@"7"])
        return NO;

    static NSSet *codes = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        codes = [NSSet setWithObjects:
            @"380", @"375", @"370", @"371", @"372", @"373", @"374", @"376", @"377", @"378",
            @"381", @"382", @"385", @"386", @"387", @"389", @"420", @"421", @"423", @"992",
            @"993", @"994", @"995", @"996", @"998", @"351", @"352", @"353", @"354", @"355",
            @"356", @"357", @"358", @"359", @"852", @"853", @"855", @"856", @"880", @"886",
            @"960", @"961", @"962", @"963", @"964", @"965", @"966", @"967", @"968", @"971",
            @"972", @"973", @"974", @"975", @"976", @"977",
            @"20", @"27", @"30", @"31", @"32", @"33", @"34", @"36", @"39", @"40",
            @"41", @"43", @"44", @"45", @"46", @"47", @"48", @"49", @"51", @"52",
            @"53", @"54", @"55", @"56", @"57", @"58", @"60", @"61", @"62", @"63",
            @"64", @"65", @"66", @"81", @"82", @"84", @"86", @"90", @"91", @"92",
            @"93", @"94", @"95", @"98", nil];
    });
    if ([codes containsObject:[digits substringToIndex:2]])
        return YES;
    if (digits.length >= 3 && [codes containsObject:[digits substringToIndex:3]])
        return YES;
    return NO;
}

/// Whether a country lookup may write the prefix. The device and network
/// lookups race; only the network answer may replace the device's, and a
/// request started for an earlier phone step must never land on this one.
static inline BOOL TGCountryGuessCanApply(NSInteger answerGeneration,
										  NSInteger currentGeneration,
										  BOOL prefixEdited,
										  BOOL resolvedByNetwork,
										  BOOL isNetwork) {
	if (prefixEdited || answerGeneration != currentGeneration)
		return NO;
	if (!isNetwork && resolvedByNetwork)
		return NO;
	return YES;
}

#endif // TGPHONENUMBERRULES_H
