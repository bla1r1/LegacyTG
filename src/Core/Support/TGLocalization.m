#import "TGLocalization.h"

NSString *const TGAppLanguageChangedNotification = @"TGAppLanguageChangedNotification";
NSString *const TGLocalizationKeyPrefix = @"@@";
static NSString *const TGAppLanguageDefaultsKey = @"TGAppLanguage";
static NSDictionary *TGTelegramLookup = nil;
/// The pack's English values lowercased, for the app's Title Case and the
/// pack's ALL CAPS / lowercase spellings of the same short label. Only
/// unambiguous, single-line entries go in: a fold collision would turn a
/// label into another screen's wording.
static NSDictionary *TGTelegramLookupFolded = nil;
/// English plural other-value -> the pack's one/few/many/other forms.
static NSDictionary *TGTelegramPlurals = nil;

static NSString *TGLocalizationFoldKey(NSString *text) {
	NSString *folded = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	folded = [folded lowercaseString];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u2019" withString:@"'"];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u2018" withString:@"'"];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u201c" withString:@"\""];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u201d" withString:@"\""];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u2013" withString:@"-"];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u2014" withString:@"-"];
	folded = [folded stringByReplacingOccurrencesOfString:@"\u2026" withString:@"..."];
	NSArray *words = [folded componentsSeparatedByCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSMutableArray *kept = [NSMutableArray arrayWithCapacity:words.count];
	for (NSString *word in words){
		if (word.length)
			[kept addObject:word];
	}
	return [kept componentsJoinedByString:@" "];
}

static void TGBuildFoldedLookup(void) {
	NSMutableDictionary *folded = [NSMutableDictionary dictionary];
	NSMutableSet *ambiguous = [NSMutableSet set];
	for (NSString *key in TGTelegramLookup){
		NSString *value = TGTelegramLookup[key];
		if (![value isKindOfClass:NSString.class] || !value.length ||
				[key hasPrefix:TGLocalizationKeyPrefix])
			continue;
		// Long paragraphs and plural forms with newline-separated variants are
		// exact-match only; folding them would guess at the wrong context.
		if ([value rangeOfString:@"\n"].location != NSNotFound || value.length > 120)
			continue;
		NSString *fold = TGLocalizationFoldKey(key);
		if (!fold.length)
			continue;
		NSString *seen = folded[fold];
		if (seen){
			if (![seen isEqualToString:value])
				[ambiguous addObject:fold];
			continue;
		}
		folded[fold] = value;
	}
	for (NSString *fold in ambiguous)
		[folded removeObjectForKey:fold];
	TGTelegramLookupFolded = folded.count ? [folded copy] : nil;
}

static NSString *TGLocalizationCachePath(NSString *packId) {
	if (!packId.length)
		return nil;
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) firstObject];
	NSString *name = [NSString stringWithFormat:@"localization-%@.plist", packId];
	return [dir stringByAppendingPathComponent:name];
}

static NSString *TGLocalizationPluralCachePath(NSString *packId) {
	if (!packId.length)
		return nil;
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) firstObject];
	NSString *name = [NSString stringWithFormat:@"localization-%@-plurals.plist", packId];
	return [dir stringByAppendingPathComponent:name];
}

static void TGLoadCachedLookup(void) {
	NSString *packId = TGAppLanguage();
	if (!packId.length || [packId isEqualToString:@"en"]){
		TGTelegramLookup = nil;
		TGTelegramLookupFolded = nil;
		TGTelegramPlurals = nil;
		return;
	}
	NSString *path = TGLocalizationCachePath(packId);
	NSDictionary *cached = path.length
			? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
	TGTelegramLookup = [cached isKindOfClass:NSDictionary.class] ? cached : nil;
	TGBuildFoldedLookup();
	NSString *pluralPath = TGLocalizationPluralCachePath(packId);
	NSDictionary *pluralCache = pluralPath.length
			? [NSDictionary dictionaryWithContentsOfFile:pluralPath] : nil;
	TGTelegramPlurals = [pluralCache isKindOfClass:NSDictionary.class]
			? pluralCache : nil;
}

static NSString *TGSystemLanguage(void) {
	NSString *code = [[NSLocale preferredLanguages] firstObject] ?: @"en";
	NSRange dash = [code rangeOfString:@"-"];
	if (dash.location != NSNotFound)
		code = [code substringToIndex:dash.location];
	return code.length ? code : @"en";
}

NSString *TGAppLanguage(void) {
	NSString *saved = [[NSUserDefaults standardUserDefaults]
			stringForKey:TGAppLanguageDefaultsKey];
	return saved.length ? saved : TGSystemLanguage();
}

BOOL TGAppLanguageIsSystem(void) {
	return [[[NSUserDefaults standardUserDefaults]
			stringForKey:TGAppLanguageDefaultsKey] length] == 0;
}

void TGSetAppLanguage(NSString *packId) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (packId.length)
		[defaults setObject:packId forKey:TGAppLanguageDefaultsKey];
	else
		[defaults removeObjectForKey:TGAppLanguageDefaultsKey];
	[defaults synchronize];
	TGLoadCachedLookup();
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAppLanguageChangedNotification object:nil];
}

void TGSetTelegramLanguageLookup(NSDictionary *englishToTranslated) {
	TGTelegramLookup = [englishToTranslated isKindOfClass:NSDictionary.class]
			? [englishToTranslated copy] : nil;
	if (!TGTelegramLookup)
		TGTelegramPlurals = nil;
	TGBuildFoldedLookup();
	NSString *packId = TGAppLanguage();
	NSString *path = TGLocalizationCachePath(packId);
	if (path.length && TGTelegramLookup) {
		NSDictionary *copy = [TGTelegramLookup copy];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			[copy writeToFile:path atomically:YES];
		});
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAppLanguageChangedNotification object:nil];
}

void TGSetTelegramLanguagePlurals(NSDictionary *englishToForms) {
	TGTelegramPlurals = [englishToForms isKindOfClass:NSDictionary.class]
			? [englishToForms copy] : nil;
	NSString *packId = TGAppLanguage();
	NSString *path = TGLocalizationPluralCachePath(packId);
	if (path.length && TGTelegramPlurals) {
		NSDictionary *copy = [TGTelegramPlurals copy];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			[copy writeToFile:path atomically:YES];
		});
	}
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAppLanguageChangedNotification object:nil];
}

NSString *TGLocalized(NSString *english) {
	if (!english.length)
		return @"";
	NSString *translated = TGTelegramLookup[english];
	if (!translated.length){
		NSString *fold = TGLocalizationFoldKey(english);
		translated = fold.length ? TGTelegramLookupFolded[fold] : nil;
	}
	return translated.length ? translated : english;
}

NSString *TGLocalizedKey(NSString *packKey, NSString *english) {
	NSString *translated = packKey.length ? TGTelegramLookup[
			[TGLocalizationKeyPrefix stringByAppendingString:packKey]] : nil;
	return translated.length ? translated : TGLocalized(english);
}

NSString *TGLocalizedOrNil(NSString *english) {
	return english.length ? TGLocalized(english) : english;
}

NSString *TGLocalizedFormat(NSString *english, ...) {
	va_list args;
	va_start(args, english);
	NSString *format = TGLocalized(english);
	NSString *answer = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	return answer;
}

static NSString *TGPluralFormKey(NSInteger count, NSString *language) {
	NSString *lang = [language lowercaseString];
	// Slavic three-form rule: 1, 2-4, 5-20 and the teens.
	if ([lang hasPrefix:@"ru"] || [lang hasPrefix:@"uk"] || [lang hasPrefix:@"be"]){
		NSInteger mod10 = count % 10;
		NSInteger mod100 = count % 100;
		if (mod10 == 1 && mod100 != 11)
			return @"one";
		if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
			return @"few";
		return @"many";
	}
	if ([lang hasPrefix:@"pl"]){
		NSInteger mod10 = count % 10;
		NSInteger mod100 = count % 100;
		if (count == 1)
			return @"one";
		if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
			return @"few";
		return @"many";
	}
	return count == 1 ? @"one" : @"other";
}

static NSString *TGPluralForm(NSString *one, NSString *other, NSInteger count) {
	NSString *form = nil;
	NSDictionary *forms = other.length ? TGTelegramPlurals[other] : nil;
	if ([forms isKindOfClass:NSDictionary.class]){
		NSString *key = TGPluralFormKey(count, TGAppLanguage());
		form = forms[key];
		if (!form.length)
			form = forms[@"other"];
		if (!form.length)
			form = forms[@"one"];
		if (!form.length)
			form = forms[@"few"];
	}
	if (!form.length)
		form = count == 1 ? one : other;
	return form;
}

NSString *TGLocalizedPlural(NSString *one, NSString *other, NSInteger count) {
	NSString *form = TGPluralForm(one, other, count);
	if (!form.length)
		return @"";
	return [NSString stringWithFormat:form, (int)count];
}

NSString *TGLocalizedPluralValue(NSString *one, NSString *other,
								 NSString *value, NSInteger count) {
	NSString *form = TGPluralForm(one, other, count);
	if (!form.length)
		return @"";
	form = [form stringByReplacingOccurrencesOfString:@"%@"
										   withString:value ?: @""];
	form = [form stringByReplacingOccurrencesOfString:@"%d"
										   withString:[NSString stringWithFormat:@"%d",
												   (int)count]];
	return form;
}

__attribute__((constructor)) static void TGLocalizationLoadAtStartup(void) {
	TGLoadCachedLookup();
}
