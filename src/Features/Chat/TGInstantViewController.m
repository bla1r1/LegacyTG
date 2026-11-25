#import "TGInstantViewController.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGUIFormat.h"
#import "TGInstantPageActions.h"
#import "TGBarItem.h"
#import "TGPresent.h"
#import "TGControls.h"
#import "TGURLSafety.h"

static NSString *const TGInstantRule = @"────────────────────────────────";

/// A tappable run: the action string TGInstantPageActions.h describes.
static NSString *const TGInstantActionAttribute = @"TGInstantAction";
/// Where an anchor sits: a zero-width run carrying the anchor's name.
static NSString *const TGInstantAnchorAttribute = @"TGInstantAnchor";

// The page is built on the main thread in one pass; these are that pass's
// state: the references a footnote link shows, the details blocks the
// reader toggled, and the running number of details blocks.
static NSMutableDictionary *TGInstantReferences;
static NSSet *TGInstantToggledDetails;
static NSInteger TGInstantDetailsCounter;

static NSAttributedString *TGInstantTappable(NSAttributedString *text, NSString *action,
											 UIColor *colour) {
	NSMutableAttributedString *out = [text mutableCopy];
	if (!out.length || !action.length)
		return out;
	[out addAttribute:TGInstantActionAttribute value:action range:NSMakeRange(0, out.length)];
	if (colour)
		[out addAttribute:NSForegroundColorAttributeName value:colour range:NSMakeRange(0, out.length)];
	return out;
}

/// Rich text is a tree of wrappers around plain runs. This builder keeps the
/// wrappers that change how a word looks - bold, italic, code, a link - and
/// drops the ones that only exist for the web layout.
static NSAttributedString *TGInstantRichText(NSDictionary *text,
											 UIFont *font,
											 UIColor *colour,
											 UIColor *linkColour);

static NSAttributedString *TGInstantPlain(NSString *string, UIFont *font,
										  UIColor *colour) {
	if (!string.length)
		return [[NSAttributedString alloc] initWithString:@""];
	return [[NSAttributedString alloc] initWithString:string
			attributes:@{NSFontAttributeName : font,
						 NSForegroundColorAttributeName : colour}];
}

static NSAttributedString *TGInstantRichText(NSDictionary *text,
											 UIFont *font,
											 UIColor *colour,
											 UIColor *linkColour) {
	if (![text isKindOfClass:NSDictionary.class])
		return TGInstantPlain(@"", font, colour);
	NSString *type = text[@"@type"] ?: @"";
	if ([type isEqualToString:@"richTextPlain"])
		return TGInstantPlain(text[@"text"] ?: @"", font, colour);
	if ([type isEqualToString:@"richTexts"]) {
		NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
		for (NSDictionary *part in text[@"texts"])
			[out appendAttributedString:TGInstantRichText(part, font, colour, linkColour)];
		return out;
	}
	if ([type isEqualToString:@"richTextBold"])
		return TGInstantRichText(text[@"text"], TGFontBoldAtSize(font.pointSize),
				colour, linkColour);
	if ([type isEqualToString:@"richTextItalic"])
		return TGInstantRichText(text[@"text"], TGFontItalicAtSize(font.pointSize),
				colour, linkColour);
	if ([type isEqualToString:@"richTextUnderline"] ||
			[type isEqualToString:@"richTextStrikethrough"]) {
		NSMutableAttributedString *out = [TGInstantRichText(text[@"text"], font,
				colour, linkColour) mutableCopy];
		NSInteger style = [type isEqualToString:@"richTextUnderline"]
				? NSUnderlineStyleSingle : NSUnderlineStyleSingle;
		NSString *key = [type isEqualToString:@"richTextUnderline"]
				? NSUnderlineStyleAttributeName : NSStrikethroughStyleAttributeName;
		[out addAttribute:key value:@(style) range:NSMakeRange(0, out.length)];
		return out;
	}
	if ([type isEqualToString:@"richTextCode"])
		return TGInstantRichText(text[@"text"],
				TGFontCodeAtSize(TGFontSizeMicro), colour, linkColour);
	if ([type isEqualToString:@"richTextUrl"]) {
		NSMutableAttributedString *out = [TGInstantRichText(text[@"text"], font,
				linkColour, linkColour) mutableCopy];
		[out addAttribute:NSUnderlineStyleAttributeName
					value:@(NSUnderlineStyleSingle)
					range:NSMakeRange(0, out.length)];
		if ([text[@"url"] isKindOfClass:NSString.class] && [text[@"url"] length])
			return TGInstantTappable(out, [@"url:" stringByAppendingString:text[@"url"]], nil);
		return out;
	}
	// In-page links (official InstantPageControllerNode findAnchorItem): an
	// anchor link scrolls to its anchor, a reference link shows the
	// reference's text, as official's reference popup does.
	if ([type isEqualToString:@"richTextAnchorLink"]) {
		NSString *name = [text[@"anchor_name"] isKindOfClass:NSString.class] ? text[@"anchor_name"] : @"";
		return TGInstantTappable(TGInstantRichText(text[@"text"], font, linkColour, linkColour),
				[@"anchor:" stringByAppendingString:name], linkColour);
	}
	if ([type isEqualToString:@"richTextReferenceLink"]) {
		NSString *name = [text[@"reference_name"] isKindOfClass:NSString.class] ? text[@"reference_name"] : @"";
		return TGInstantTappable(TGInstantRichText(text[@"text"], font, linkColour, linkColour),
				[@"ref:" stringByAppendingString:name], linkColour);
	}
	if ([type isEqualToString:@"richTextReference"]) {
		NSAttributedString *body = TGInstantRichText(text[@"text"], font, colour, linkColour);
		if ([text[@"name"] isKindOfClass:NSString.class] && body.length)
			TGInstantReferences[text[@"name"]] = body.string;
		return body;
	}
	if ([type isEqualToString:@"richTextAnchor"]) {
		NSString *name = [text[@"name"] isKindOfClass:NSString.class] ? text[@"name"] : @"";
		return [[NSAttributedString alloc] initWithString:@"\u200B"
				attributes:@{NSFontAttributeName : font, TGInstantAnchorAttribute : name}];
	}
	if ([type isEqualToString:@"richTextCustomEmoji"])
		return TGInstantPlain(text[@"alternative_text"] ?: @"", font, colour);
	if ([type isEqualToString:@"richTextIcon"])
		return TGInstantPlain(@"", font, colour);
	if ([type isEqualToString:@"richTextButton"])
		return TGInstantRichText(text[@"button"][@"text"], font, linkColour, linkColour);
	if ([type isEqualToString:@"richTextEmailAddress"] ||
			[type isEqualToString:@"richTextPhoneNumber"] ||
			[type isEqualToString:@"richTextMention"] ||
			[type isEqualToString:@"richTextHashtag"] ||
			[type isEqualToString:@"richTextCashtag"] ||
			[type isEqualToString:@"richTextBankCard"] ||
			[type isEqualToString:@"richTextMarked"] ||
			[type isEqualToString:@"richTextSubscript"] ||
			[type isEqualToString:@"richTextSuperscript"])
		return TGInstantRichText(text[@"text"], font, colour, linkColour);
	// Every other node is a wrapper whose `text` is the content.
	if (text[@"text"])
		return TGInstantRichText(text[@"text"], font, colour, linkColour);
	if (text[@"url"])
		return TGInstantPlain(text[@"url"], font, colour);
	return TGInstantPlain(@"", font, colour);
}

static NSAttributedString *TGInstantCaption(NSDictionary *caption,
											UIColor *colour) {
	NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
	NSAttributedString *text = TGInstantRichText(caption[@"text"],
			TGFontCaption(), colour, [[TGTheme shared] accentColour]);
	[out appendAttributedString:text];
	NSAttributedString *credit = TGInstantRichText(caption[@"credit"],
			TGFontCaption(), [[TGTheme shared] secondaryTextColour],
			[[TGTheme shared] accentColour]);
	if (credit.length) {
		[out appendAttributedString:TGInstantPlain(@" — ", TGFontCaption(), colour)];
		[out appendAttributedString:credit];
	}
	return out;
}

static void TGInstantAppendAligned(NSMutableAttributedString *out,
							NSAttributedString *text,
							CGFloat indent,
							CGFloat before,
							CGFloat after,
							NSTextAlignment alignment) {
	if (!text.length)
		return;
	NSMutableAttributedString *piece = [text mutableCopy];
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	style.alignment = alignment;
	style.firstLineHeadIndent = indent;
	style.headIndent = indent;
	style.paragraphSpacingBefore = before;
	style.paragraphSpacing = after;
	style.lineSpacing = TGMetricPadTiny;
	[piece addAttribute:NSParagraphStyleAttributeName
				  value:style
				  range:NSMakeRange(0, piece.length)];
	[out appendAttributedString:piece];
	NSMutableAttributedString *ending = [[NSMutableAttributedString alloc]
			initWithString:@"\n" attributes:@{
				NSFontAttributeName : TGFontBody(),
				NSForegroundColorAttributeName : [UIColor clearColor],
				NSParagraphStyleAttributeName : style,
			}];
	[out appendAttributedString:ending];
}

static void TGInstantAppend(NSMutableAttributedString *out,
							NSAttributedString *text,
							CGFloat indent,
							CGFloat before,
							CGFloat after) {
	TGInstantAppendAligned(out, text, indent, before, after, NSTextAlignmentLeft);
}

static void TGInstantAppendBlocks(NSMutableAttributedString *out,
								  NSArray *blocks,
								  CGFloat indent,
								  TGTheme *theme);

static void TGInstantAppendBlock(NSMutableAttributedString *out,
								 NSDictionary *block,
								 CGFloat indent,
								 TGTheme *theme) {
	if (![block isKindOfClass:NSDictionary.class])
		return;
	NSString *type = block[@"@type"] ?: @"";
	UIColor *primary = [theme primaryTextColour];
	UIColor *secondary = [theme secondaryTextColour];
	UIColor *accent = [theme accentColour];

	if ([type isEqualToString:@"pageBlockTitle"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"title"], TGFontTitle(),
				primary, accent), indent, TGMetricPadLarge, TGMetricPad);
		return;
	}
	if ([type isEqualToString:@"pageBlockSubtitle"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"subtitle"], TGFontBody(),
				secondary, accent), indent, TGMetricZero, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockHeader"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"header"], TGFontHeader(),
				primary, accent), indent, TGMetricPadLarge, TGMetricPadSmall);
		return;
	}
	if ([type isEqualToString:@"pageBlockSubheader"] ||
			[type isEqualToString:@"pageBlockSectionHeading"]) {
		NSDictionary *text = block[@"subheader"] ? block[@"subheader"] : block[@"text"];
		TGInstantAppend(out, TGInstantRichText(text, TGFontRowStrong(), primary,
				accent), indent, TGMetricPadMedium, TGMetricPadSmall);
		return;
	}
	if ([type isEqualToString:@"pageBlockKicker"]) {
		NSAttributedString *kicker = TGInstantRichText(block[@"kicker"],
				TGFontMetaStrong(), secondary, accent);
		NSMutableAttributedString *upper = [kicker mutableCopy];
		NSString *string = [[upper string] uppercaseString];
		[upper replaceCharactersInRange:NSMakeRange(0, upper.length) withString:string];
		TGInstantAppend(out, upper, indent, TGMetricPad, TGMetricPadTiny);
		return;
	}
	if ([type isEqualToString:@"pageBlockParagraph"] ||
			[type isEqualToString:@"pageBlockThinking"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"text"], TGFontBody(),
				primary, accent), indent, TGMetricZero, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockPreformatted"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"text"],
				TGFontCodeAtSize(TGFontSizeMicro), primary, accent),
				indent + TGMetricPadLarge, TGMetricPadSmall, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockFooter"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"footer"], TGFontCaption(),
				secondary, accent), indent, TGMetricPadMedium, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockDivider"]) {
		TGInstantAppend(out, TGInstantPlain(TGInstantRule, TGFontCaption(), secondary),
				indent, TGMetricPadMedium, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockAuthorDate"]) {
		NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
		NSString *author = TGInstantRichText(block[@"author"],
				TGFontCaption(), secondary, accent).string;
		NSNumber *date = [block[@"publish_date"] isKindOfClass:NSNumber.class]
				? block[@"publish_date"] : nil;
		NSString *when = TGAppDate(date.doubleValue, NSDateFormatterMediumStyle,
				NSDateFormatterNoStyle);
		NSString *joined = nil;
		if (author.length && when.length)
			joined = TGLocalizedFormat(@"%1$@, %2$@", author, when);
		else
			joined = author.length ? author : when;
		if (joined.length)
			[line appendAttributedString:TGInstantPlain(joined, TGFontCaption(), secondary)];
		TGInstantAppend(out, line, indent, TGMetricPadSmall, TGMetricPadLarge);
		return;
	}
	if ([type isEqualToString:@"pageBlockPullQuote"] ||
			[type isEqualToString:@"pageBlockExpandableBlockQuote"]) {
		NSMutableAttributedString *quote = [[NSMutableAttributedString alloc] init];
		[quote appendAttributedString:TGInstantPlain(@"“", TGFontBody(), secondary)];
		[quote appendAttributedString:TGInstantRichText(block[@"text"],
				TGFontItalicAtSize(TGFontBody().pointSize), primary, accent)];
		[quote appendAttributedString:TGInstantPlain(@"”", TGFontBody(), secondary)];
		TGInstantAppend(out, quote, indent + TGMetricPadLarge,
				TGMetricPadMedium, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockBlockQuote"]) {
		TGInstantAppend(out, TGInstantPlain(@"“", TGFontBody(), secondary),
				indent + TGMetricPadLarge, TGMetricPadMedium, TGMetricZero);
		TGInstantAppendBlocks(out, block[@"blocks"], indent + TGMetricPadLarge, theme);
		NSAttributedString *credit = TGInstantRichText(block[@"credit"],
				TGFontCaption(), secondary, accent);
		if (credit.length) {
			NSMutableAttributedString *line = [NSMutableAttributedString new];
			[line appendAttributedString:TGInstantPlain(@"— ", TGFontCaption(), secondary)];
			[line appendAttributedString:credit];
			TGInstantAppend(out, line, indent + TGMetricPadLarge,
					TGMetricZero, TGMetricPadMedium);
		}
		return;
	}
	if ([type isEqualToString:@"pageBlockList"]) {
		for (NSDictionary *item in block[@"items"]) {
			NSString *label = item[@"label"];
			if (!label.length)
				label = @"•";
			NSMutableAttributedString *lead = [[NSMutableAttributedString alloc]
					initWithAttributedString:TGInstantPlain(
							[NSString stringWithFormat:@"%@  ", label],
							TGFontBody(), secondary)];
			[out appendAttributedString:lead];
			NSMutableAttributedString *itemText = [[NSMutableAttributedString alloc] init];
			TGInstantAppendBlocks(itemText, item[@"blocks"], TGMetricZero, theme);
			TGInstantAppend(out, itemText, indent + TGMetricPadLarge,
					TGMetricZero, TGMetricPadSmall);
		}
		return;
	}
	// Details open as the page says and fold on a tap of the header
	// (official InstantPageDetailsItem, pageBlockDetails.is_open).
	if ([type isEqualToString:@"pageBlockDetails"]) {
		NSInteger number = TGInstantDetailsCounter++;
		BOOL open = [block[@"is_open"] boolValue] != [TGInstantToggledDetails containsObject:@(number)];
		NSMutableAttributedString *header = [TGInstantPlain(open ? @"▾ " : @"▸ ",
				TGFontBodyStrong(), secondary) mutableCopy];
		[header appendAttributedString:TGInstantRichText(block[@"header"], TGFontBodyStrong(),
				primary, accent)];
		TGInstantAppend(out, TGInstantTappable(header,
				[NSString stringWithFormat:@"details:%ld", (long)number], nil),
				indent, TGMetricPadMedium, TGMetricPadSmall);
		if (open)
			TGInstantAppendBlocks(out, block[@"blocks"], indent + TGMetricPadLarge, theme);
		return;
	}
	// A row of buttons, each a tappable label, set where the page aligns it.
	if ([type isEqualToString:@"pageBlockButtonRow"]) {
		NSMutableAttributedString *row = [[NSMutableAttributedString alloc] init];
		for (NSDictionary *button in block[@"buttons"]) {
			NSAttributedString *label = TGInstantRichText(button[@"text"], TGFontBodyStrong(), accent, accent);
			if (!label.length)
				continue;
			if (row.length)
				[row appendAttributedString:TGInstantPlain(@"     ", TGFontBody(), primary)];
			NSString *action = TGInstantButtonAction(button);
			[row appendAttributedString:action ? TGInstantTappable(label, action, nil) : label];
		}
		TGInstantAppendAligned(out, row, indent, TGMetricPadSmall, TGMetricPadMedium,
				(NSTextAlignment)TGInstantAlignment(block[@"align"]));
		return;
	}
	if ([type isEqualToString:@"pageBlockAnchor"]) {
		NSString *name = [block[@"name"] isKindOfClass:NSString.class] ? block[@"name"] : @"";
		[out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u200B"
				attributes:@{NSFontAttributeName : TGFontBody(), TGInstantAnchorAttribute : name}]];
		return;
	}
	if ([type isEqualToString:@"pageBlockCollage"] ||
			[type isEqualToString:@"pageBlockSlideshow"]) {
		TGInstantAppendBlocks(out, block[@"blocks"], indent, theme);
		NSAttributedString *caption = TGInstantCaption(block[@"caption"], secondary);
		if (caption.length)
			TGInstantAppend(out, caption, indent, TGMetricZero, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockPhoto"] ||
			[type isEqualToString:@"pageBlockVideo"] ||
			[type isEqualToString:@"pageBlockAnimation"] ||
			[type isEqualToString:@"pageBlockAudio"] ||
			[type isEqualToString:@"pageBlockVoiceNote"] ||
			[type isEqualToString:@"pageBlockDocument"]) {
		NSString *name = TGLocalized(@"Photo");
		if ([type isEqualToString:@"pageBlockVideo"])
			name = TGLocalized(@"Video");
		else if ([type isEqualToString:@"pageBlockAnimation"])
			name = TGLocalized(@"GIF");
		else if ([type isEqualToString:@"pageBlockAudio"])
			name = TGLocalized(@"Audio");
		else if ([type isEqualToString:@"pageBlockVoiceNote"])
			name = TGLocalized(@"Voice message");
		else if ([type isEqualToString:@"pageBlockDocument"])
			name = TGLocalized(@"File");
		NSAttributedString *caption = TGInstantCaption(block[@"caption"], secondary);
		NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
		[line appendAttributedString:TGInstantPlain(name, TGFontCaption(), secondary)];
		if (caption.length) {
			[line appendAttributedString:TGInstantPlain(@" — ", TGFontCaption(), secondary)];
			[line appendAttributedString:caption];
		}
		TGInstantAppend(out, line, indent, TGMetricPadSmall, TGMetricPadMedium);
		return;
	}
	if ([type isEqualToString:@"pageBlockCover"]) {
		TGInstantAppendBlock(out, block[@"cover"], indent, theme);
		return;
	}
	if ([type isEqualToString:@"pageBlockEmbedded"] ||
			[type isEqualToString:@"pageBlockEmbeddedPost"]) {
		NSAttributedString *caption = TGInstantCaption(block[@"caption"], secondary);
		NSString *url = block[@"url"];
		if (!caption.length)
			caption = TGInstantPlain(url ?: @"Embedded content", TGFontCaption(), secondary);
		TGInstantAppend(out, caption, indent, TGMetricPadSmall, TGMetricPadMedium);
		if ([type isEqualToString:@"pageBlockEmbeddedPost"])
			TGInstantAppendBlocks(out, block[@"blocks"], indent + TGMetricPadLarge, theme);
		return;
	}
	if ([type isEqualToString:@"pageBlockTable"]) {
		for (NSArray *row in block[@"cells"]) {
			NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
			for (NSDictionary *cell in row) {
				if (line.length)
					[line appendAttributedString:TGInstantPlain(@"  |  ", TGFontCaption(), secondary)];
				// A header cell reads bold, as official's table draws it.
				UIFont *cellFont = [cell[@"is_header"] boolValue]
						? TGFontBoldAtSize(TGFontCaption().pointSize) : TGFontCaption();
				[line appendAttributedString:TGInstantRichText(cell[@"text"],
						cellFont, primary, accent)];
			}
			TGInstantAppend(out, line, indent, TGMetricPadTiny, TGMetricPadTiny);
		}
		return;
	}
	if ([type isEqualToString:@"pageBlockRelatedArticles"]) {
		TGInstantAppend(out, TGInstantRichText(block[@"header"], TGFontBodyStrong(),
				primary, accent), indent, TGMetricPadMedium, TGMetricPadSmall);
		for (NSDictionary *article in block[@"articles"]) {
			NSString *title = article[@"title"] ?: article[@"url"] ?: @"";
			TGInstantAppend(out, TGInstantPlain(
					[NSString stringWithFormat:@"•  %@", title],
					TGFontBody(), primary),
					indent + TGMetricPadLarge, TGMetricZero, TGMetricPadSmall);
		}
		return;
	}
	if ([type isEqualToString:@"pageBlockChatLink"]) {
		TGInstantAppend(out, TGInstantPlain(block[@"title"] ?: block[@"username"] ?: @"",
				TGFontBodyStrong(), accent), indent, TGMetricPadSmall, TGMetricPadMedium);
		return;
	}
	// Anchors and markup the reader has no use for are simply absent.
	if ([type isEqualToString:@"pageBlockUnsupported"] ||
			[type isEqualToString:@"pageBlockMathematicalExpression"])
		return;
}

static void TGInstantAppendBlocks(NSMutableAttributedString *out,
								  NSArray *blocks,
								  CGFloat indent,
								  TGTheme *theme) {
	for (NSDictionary *block in blocks)
		TGInstantAppendBlock(out, block, indent, theme);
}

@interface TGInstantViewController () <UITextViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, weak) UITextView *reader;
@property (nonatomic, copy) NSSet *toggledDetails;
@property (nonatomic, copy) NSDictionary *references;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@end

@implementation TGInstantViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];
	self.title = self.pageSiteName.length ? self.pageSiteName
			: (self.pageTitle.length ? self.pageTitle : @"Instant View");

	// Site name in the bar with two icon actions; no text "Action".
	UIBarButtonItem *more = [TGBarItem itemWithRole:TGBarRoleMore
			target:self action:@selector(showActions)];
	UIBarButtonItem *share = [TGBarItem itemWithRole:TGBarRoleShare
			target:self action:@selector(sharePage)];
	self.navigationItem.rightBarButtonItems = @[more, share];

	UITextView *reader = TGReaderTextView(self.view.bounds);
	reader.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	reader.delegate = self;
	reader.backgroundColor = [theme listBackgroundColour];
	reader.textColor = [theme primaryTextColour];
	reader.font = TGFontBody();
	reader.dataDetectorTypes = UIDataDetectorTypeLink;
	reader.contentInset = UIEdgeInsetsMake(TGMetricPadLarge, TGMetricPadLarge,
										   TGMetricPadLarge, TGMetricPadLarge);
	reader.scrollIndicatorInsets = reader.contentInset;

	reader.attributedText = [self readerText];
	[self.view addSubview:reader];
	self.reader = reader;
	// Links, anchors, details and buttons are runs in the text; iOS 6's text
	// view has no link attribute, so a tap finds its run through the text
	// position under the finger.
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
			action:@selector(readerTapped:)];
	tap.cancelsTouchesInView = NO;
	tap.delegate = self;
	[reader addGestureRecognizer:tap];

	// A 2 pt reading-progress line under the bar.
	CGFloat line = TGMetricBorderThick;
	self.progressTrack = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
			self.view.bounds.size.width, line)];
	self.progressTrack.backgroundColor = [theme separatorColour];
	self.progressTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.progressFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, line)];
	self.progressFill.backgroundColor = [theme accentColour];
	[self.progressTrack addSubview:self.progressFill];
	[self.view addSubview:self.progressTrack];

	[self applyThemeToReader:reader];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:TGThemeChangedNotification object:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat room = scrollView.contentSize.height - scrollView.bounds.size.height;
	CGFloat part = room > 0 ? (scrollView.contentOffset.y + scrollView.contentInset.top) / room : 1;
	part = MAX(0, MIN(1, part));
	CGRect f = self.progressFill.frame;
	f.size.width = self.view.bounds.size.width * part;
	self.progressFill.frame = f;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	// The page carries its colours inside the attributed text, so a new theme
	// means laying it out again.
	self.reader.attributedText = [self readerText];
	[self applyThemeToReader:self.reader];
}

- (NSAttributedString *)readerText {
	TGTheme *theme = [TGTheme shared];
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
	TGInstantReferences = [NSMutableDictionary dictionary];
	TGInstantToggledDetails = self.toggledDetails ?: [NSSet set];
	TGInstantDetailsCounter = 0;
	TGInstantAppendBlocks(text, self.blocks, TGMetricZero, theme);
	self.references = TGInstantReferences;
	// Official's last row: "Wrong layout?" to the previews bot
	// (InstantPageFeedbackItem, webPageInstantView.feedback_link).
	if (TGInstantFeedbackURL(self.feedbackLink).length)
		TGInstantAppendAligned(text, TGInstantTappable(TGInstantPlain(TGLocalized(@"Wrong layout?"),
				TGFontCaption(), [theme secondaryTextColour]), @"feedback", nil),
				TGMetricZero, TGMetricPadLarge, TGMetricPadLarge, NSTextAlignmentCenter);
	if (!self.blocks.count) {
		[text appendAttributedString:TGInstantPlain(
				@"Telegram returned an empty page.", TGFontBody(),
				[theme secondaryTextColour])];
	}
	return text;
}

- (void)applyThemeToReader:(UITextView *)reader {
	reader.backgroundColor = [[TGTheme shared] listBackgroundColour];
	reader.textColor = [[TGTheme shared] primaryTextColour];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
		shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	return YES;
}

- (void)readerTapped:(UITapGestureRecognizer *)tap {
	UITextView *reader = self.reader;
	NSAttributedString *text = reader.attributedText;
	UITextPosition *position = [reader closestPositionToPoint:[tap locationInView:reader]];
	if (!position || !text.length)
		return;
	NSInteger index = [reader offsetFromPosition:reader.beginningOfDocument toPosition:position];
	NSString *action = nil;
	for (NSInteger at = index; at >= MAX(0, index - 1) && !action; at--)
		if (at < (NSInteger)text.length)
			action = [text attribute:TGInstantActionAttribute atIndex:(NSUInteger)at effectiveRange:NULL];
	if (action.length)
		[self runAction:action];
}

- (void)runAction:(NSString *)action {
	if ([action hasPrefix:@"anchor:"]) {
		[self scrollToAnchor:[action substringFromIndex:7]];
	} else if ([action hasPrefix:@"ref:"]) {
		NSString *body = self.references[[action substringFromIndex:4]];
		if (body.length)
			[TGAlertSheet showMessage:body title:nil inView:self.view];
	} else if ([action hasPrefix:@"details:"]) {
		NSNumber *number = @([[action substringFromIndex:8] integerValue]);
		NSMutableSet *toggled = [self.toggledDetails mutableCopy] ?: [NSMutableSet set];
		if ([toggled containsObject:number])
			[toggled removeObject:number];
		else
			[toggled addObject:number];
		self.toggledDetails = toggled;
		CGPoint offset = self.reader.contentOffset;
		self.reader.attributedText = [self readerText];
		self.reader.contentOffset = offset;
	} else if ([action hasPrefix:@"url:"]) {
		NSURL *url = [NSURL URLWithString:[action substringFromIndex:4]];
		if (url)
			TGOpenSafeExternalURL(url);
	} else if ([action hasPrefix:@"copy:"]) {
		[UIPasteboard generalPasteboard].string = [action substringFromIndex:5];
		[TGAlertSheet showMessage:TGLocalized(@"Copied to clipboard.") title:nil inView:self.view];
	} else if ([action isEqualToString:@"feedback"]) {
		NSURL *url = [NSURL URLWithString:TGInstantFeedbackURL(self.feedbackLink) ?: @""];
		if (url)
			TGOpenSafeExternalURL(url);
	}
}

/// An empty name goes back to the top, as TDLib documents for anchor links.
- (void)scrollToAnchor:(NSString *)name {
	UITextView *reader = self.reader;
	if (!name.length) {
		[reader setContentOffset:CGPointMake(0, -reader.contentInset.top) animated:YES];
		return;
	}
	__block NSRange found = NSMakeRange(NSNotFound, 0);
	[reader.attributedText enumerateAttribute:TGInstantAnchorAttribute
			inRange:NSMakeRange(0, reader.attributedText.length) options:0
		 usingBlock:^(id value, NSRange range, BOOL *stop){
		if ([value isKindOfClass:NSString.class] && [value isEqualToString:name]) {
			found = range;
			*stop = YES;
		}
	}];
	if (found.location == NSNotFound)
		return;
	UITextPosition *start = [reader positionFromPosition:reader.beginningOfDocument
												  offset:(NSInteger)found.location];
	UITextPosition *end = [reader positionFromPosition:start offset:1];
	if (!start || !end)
		return;
	CGRect rect = [reader firstRectForRange:[reader textRangeFromPosition:start toPosition:end]];
	CGFloat maxY = MAX(0, reader.contentSize.height - reader.bounds.size.height);
	[reader setContentOffset:CGPointMake(0, MIN(maxY, MAX(-reader.contentInset.top, rect.origin.y)))
					animated:YES];
}

- (void)showActions {
	NSMutableArray *choices = [NSMutableArray arrayWithObject:
			@{@"title" : @"Open in Browser", @"icon" : @"forward"}];
	if (self.sourceURL.length)
		[choices addObject:@{@"title" : @"Copy Link", @"icon" : @"copy"}];
	__weak typeof(self) weakSelf = self;
	[TGPresent showMenu:choices fromBarItem:self.navigationItem.rightBarButtonItems.firstObject
				   side:TGBarSideRight onController:self
			   onChoice:^(NSInteger index, NSString *title){
		TGInstantViewController *me = weakSelf;
		if (!me)
			return;
		if (index == 0) {
			NSURL *url = [NSURL URLWithString:me.sourceURL ?: @""];
			if (!url || !TGIsSafeExternalURL(url) || ![[UIApplication sharedApplication] canOpenURL:url]) {
				[TGAlertSheet showMessage:@"There is no address for this page."
									  title:@"Instant View" inView:me.view];
				return;
			}
			TGOpenSafeExternalURL(url);
			return;
		}
		[UIPasteboard generalPasteboard].string = me.sourceURL;
		[TGAlertSheet showMessage:@"The address is on the clipboard."
							  title:@"Link copied." inView:me.view];
	}];
}

- (void)sharePage {
	NSURL *url = [NSURL URLWithString:self.sourceURL ?: @""];
	if (!url)
		return;
	[TGPresent shareItems:@[url] from:self sourceView:self.view];
}

@end
