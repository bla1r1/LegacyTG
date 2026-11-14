// TGPageTemplateTests.m - the six page kinds and the chrome each one gets.
// Two screens of one kind must come out the same; these pin what "the same"
// means.
#import "TGTestRunner.h"
#import "TGPageTemplate.h"
#import "TGStyle.h"

@interface TGPageTemplateTests : XCTestCase @end

@implementation TGPageTemplateTests

- (void)testKinds_GroupedCardsOrWhiteRowsOnThePage {
	for (NSInteger i = 0; i < TGPageKindCount; i++){
		TGPageKind kind = (TGPageKind)i;
		TGPageChrome c = TGPageChromeFor([TGPageTemplate templateWithKind:kind], NO);
		BOOL plain = kind == TGPageKindList || kind == TGPageKindPicker;
		XCTAssertEqual(c.grouped, !plain, @"%@", TGPageKindName(kind));
		// A plain list never shows its rows on a white sheet: they are white
		// cards on the page, as a grouped page's are.
		XCTAssertEqual(c.whiteRowsOnPage, plain, @"%@", TGPageKindName(kind));
	}
}

- (void)testDefaults_EachKindHasItsParts {
	XCTAssertTrue(TGPageChromeFor([TGPageTemplate templateWithKind:TGPageKindList], NO).searchInList);
	XCTAssertTrue(TGPageChromeFor([TGPageTemplate templateWithKind:TGPageKindDetail], NO).header);
	TGPageChrome picker = TGPageChromeFor([TGPageTemplate templateWithKind:TGPageKindPicker], NO);
	XCTAssertTrue(picker.searchInList && picker.bottomBar);
	XCTAssertEqual(picker.bottomBarHeight, (CGFloat)(TGMetricRow + 2 * TGMetricPad));
	XCTAssertTrue(TGPageChromeFor([TGPageTemplate templateWithKind:TGPageKindForm], NO).rightItem);
	TGPageChrome settings = TGPageChromeFor([TGPageTemplate templateWithKind:TGPageKindSettings], NO);
	XCTAssertFalse(settings.header || settings.searchInList || settings.bottomBar || settings.rightItem);
}

- (void)testBar_BackClosesASheetAndMakesRoomForABarSearch {
	TGPageTemplate *page = [TGPageTemplate templateWithKind:TGPageKindPicker];
	XCTAssertEqual(TGPageChromeFor(page, NO).leftItem, TGPageLeftBack);
	XCTAssertEqual(TGPageChromeFor(page, YES).leftItem, TGPageLeftClose);
	page.search = TGPageSearchInBar;
	page.barActionTitle = @"Done";
	TGPageChrome bar = TGPageChromeFor(page, NO);
	// The field takes the bar: no Back over it (it showed through on iOS 6)
	// and no right button beside Cancel.
	XCTAssertEqual(bar.leftItem, TGPageLeftNone);
	XCTAssertTrue(bar.titleInBar);
	XCTAssertFalse(bar.rightItem);
	XCTAssertFalse(bar.searchInList);
}

- (void)testToggles_PartsTurnOnAndOff {
	TGPageTemplate *page = [TGPageTemplate templateWithKind:TGPageKindGallery];
	XCTAssertFalse(TGPageChromeFor(page, NO).scopes);
	page.scopeTitles = @[@"Media"];
	XCTAssertFalse(TGPageChromeFor(page, NO).scopes, @"one scope is not a choice");
	page.scopeTitles = @[@"Media", @"Files"];
	XCTAssertTrue(TGPageChromeFor(page, NO).scopes);
	page.headerTitle = @"Album";
	XCTAssertTrue(TGPageChromeFor(page, NO).header);
	page.bottomActionTitle = @"Add";
	XCTAssertTrue(TGPageChromeFor(page, NO).bottomBar);
}

- (void)testEmpty_OnlyWhenNoSectionHasARowAndThereIsSomethingToSay {
	TGPageTemplate *page = [TGPageTemplate templateWithKind:TGPageKindList];
	NSArray *empty = @[@{@"rows" : @[]}, @{@"header" : @"x", @"rows" : @[]}];
	XCTAssertFalse(TGPageShowsEmpty(page, empty), @"no title: nothing to show");
	page.emptyTitle = @"No Results";
	XCTAssertTrue(TGPageShowsEmpty(page, empty));
	XCTAssertTrue(TGPageShowsEmpty(page, nil));
	XCTAssertFalse(TGPageShowsEmpty(page, @[@{@"rows" : @[@{}]}]));
}

@end
