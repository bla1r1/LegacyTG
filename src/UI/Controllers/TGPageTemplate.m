//
// TGPageTemplate.m
//
#import "TGPageTemplate.h"
#import "TGStyle.h"

@implementation TGPageTemplate

+ (instancetype)templateWithKind:(TGPageKind)kind {
	TGPageTemplate *page = [[self alloc] init];
	page.kind = kind;
	switch (kind){
		case TGPageKindList:
			page.search = TGPageSearchInList;
			page.searchPlaceholder = @"Search";
			break;
		case TGPageKindDetail:
			page.headerArtSide = TGMetricPageArtSide;
			break;
		case TGPageKindPicker:
			page.search = TGPageSearchInList;
			page.searchPlaceholder = @"Search";
			page.bottomActionTitle = @"Send";
			break;
		case TGPageKindForm:
			page.barActionTitle = @"Done";
			break;
		case TGPageKindSettings:
		case TGPageKindGallery:
			break;
	}
	return page;
}

@end

TGPageChrome TGPageChromeFor(TGPageTemplate *page, BOOL firstInSheet) {
	TGPageChrome c;
	memset(&c, 0, sizeof c);
	TGPageKind kind = page.kind;
	c.grouped = kind != TGPageKindList && kind != TGPageKindPicker;
	c.whiteRowsOnPage = !c.grouped;
	c.titleInBar = page.search == TGPageSearchInBar;
	// The bar search brings its own Cancel and needs the bar's width; a
	// sheet's first screen has no Back to show, so it closes.
	if (c.titleInBar)
		c.leftItem = TGPageLeftNone;
	else
		c.leftItem = firstInSheet ? TGPageLeftClose : TGPageLeftBack;
	// Cancel sits on the right of a bar search; there is no room for more.
	c.rightItem = page.barActionTitle.length > 0 && !c.titleInBar;
	c.header = page.headerArtSide > 0 || page.headerTitle.length ||
			page.headerSubtitle.length || page.headerText.length;
	c.searchInList = page.search == TGPageSearchInList;
	c.scopes = page.scopeTitles.count > 1;
	c.bottomBar = page.bottomActionTitle.length > 0;
	c.bottomBarHeight = c.bottomBar ? TGMetricRow + TGDoubled(TGMetricPad) : 0;
	return c;
}

BOOL TGPageShowsEmpty(TGPageTemplate *page, NSArray *sections) {
	if (!page.emptyTitle.length && !page.emptySubtitle.length)
		return NO;
	for (NSDictionary *section in sections){
		NSArray *rows = [section isKindOfClass:NSDictionary.class] ? section[@"rows"] : nil;
		if ([rows isKindOfClass:NSArray.class] && rows.count)
			return NO;
	}
	return YES;
}

NSString *TGPageKindName(TGPageKind kind) {
	switch (kind){
		case TGPageKindSettings: return @"Settings";
		case TGPageKindList:     return @"List";
		case TGPageKindDetail:   return @"Detail";
		case TGPageKindPicker:   return @"Picker";
		case TGPageKindForm:     return @"Form";
		case TGPageKindGallery:  return @"Gallery";
	}
	return @"Page";
}
