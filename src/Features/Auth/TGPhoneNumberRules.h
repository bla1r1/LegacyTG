//
// TGPhoneNumberRules.h - the split rule for a typed phone number.
//
// Only a + or 00 makes typed digits international. Guessing a calling code
// from the first digits moved real national numbers into the code field:
// Kyrgyz 555... became Brazil's +55, 996... a second +996, Russian 916...
// India's +91, so the number sent was wrong and the code never arrived.
// Official never splits what is typed in the number field.
//
#ifndef TGPHONENUMBERRULES_H
#define TGPHONENUMBERRULES_H

#import <Foundation/Foundation.h>

static inline BOOL TGPhoneNumberLooksInternational(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || !text.length)
        return NO;
    return [text hasPrefix:@"+"] || [text hasPrefix:@"00"];
}

/// How many leading digits of a number written after + are its calling code.
/// +1 and +7 are the one-digit codes; without this +7 701... became +770.
/// Unknown codes take three digits, the longest a calling code has.
static inline NSUInteger TGPhoneCallingCodeLength(NSString *digits) {
    if (![digits isKindOfClass:[NSString class]] || !digits.length)
        return 0;
    static NSSet *three = nil, *two = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        three = [NSSet setWithObjects:
            @"380", @"375", @"370", @"371", @"372", @"373", @"374", @"376", @"377", @"378",
            @"381", @"382", @"385", @"386", @"387", @"389", @"420", @"421", @"423", @"992",
            @"993", @"994", @"995", @"996", @"998", @"351", @"352", @"353", @"354", @"355",
            @"356", @"357", @"358", @"359", @"852", @"853", @"855", @"856", @"880", @"886",
            @"960", @"961", @"962", @"963", @"964", @"965", @"966", @"967", @"968", @"971",
            @"972", @"973", @"974", @"975", @"976", @"977", nil];
        two = [NSSet setWithObjects:
            @"20", @"27", @"30", @"31", @"32", @"33", @"34", @"36", @"39", @"40",
            @"41", @"43", @"44", @"45", @"46", @"47", @"48", @"49", @"51", @"52",
            @"53", @"54", @"55", @"56", @"57", @"58", @"60", @"61", @"62", @"63",
            @"64", @"65", @"66", @"81", @"82", @"84", @"86", @"90", @"91", @"92",
            @"93", @"94", @"95", @"98", nil];
    });
    if (digits.length >= 3 && [three containsObject:[digits substringToIndex:3]])
        return 3;
    if (digits.length >= 2 && [two containsObject:[digits substringToIndex:2]])
        return 2;
    if ([digits hasPrefix:@"1"] || [digits hasPrefix:@"7"])
        return 1;
    return MIN((NSUInteger)3, digits.length);
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
