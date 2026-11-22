//
// TGLabel.m
//
#import "TGLabel.h"
#import "TGStyle.h"
#import "TGTheme.h"

UILabel *TGLabelMake(TGLabelRole role) {
	TGTheme *theme = [TGTheme shared];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.backgroundColor = [UIColor clearColor];
	UIFont *font = TGFontBody();
	UIColor *colour = [theme primaryTextColour];
	switch (role){
	case TGLabelTitle:         font = TGFontTitle(); break;
	case TGLabelHeader:        font = TGFontHeader(); break;
	case TGLabelRow:           font = TGFontRow(); break;
	case TGLabelRowStrong:     font = TGFontRowStrong(); break;
	case TGLabelBody:          break;
	case TGLabelBodySecondary: colour = [theme secondaryTextColour]; break;
	case TGLabelSubhead:       font = TGFontSubhead(); colour = [theme secondaryTextColour]; break;
	case TGLabelCaption:       font = TGFontCaption(); colour = [theme secondaryTextColour]; break;
	case TGLabelCaptionStrong: font = TGFontCaptionStrong(); break;
	case TGLabelMeta:          font = TGFontMeta(); colour = [theme secondaryTextColour]; break;
	case TGLabelMicro:         font = TGFontMicro(); colour = [theme secondaryTextColour]; break;
	case TGLabelSectionHeader:
		font = TGFontHeader();
		colour = [theme sectionHeaderColour];
		TGLabelEtch(label);
		break;
	case TGLabelBarTitle:
		font = TGFontHeader();
		colour = [theme barTitleColour];
		label.shadowColor = [theme navBarTextShadowColour];
		label.shadowOffset = TGMetricShadowOffsetNav;
		break;
	case TGLabelBarSubtitle:
		font = TGFontMeta();
		colour = [theme barSubtitleColour];
		break;
	}
	label.font = font;
	label.textColor = colour;
	return label;
}

UILabel *TGLabelWith(TGLabelRole role, CGRect frame, NSString *text) {
	UILabel *label = TGLabelMake(role);
	label.frame = frame;
	label.text = text;
	return label;
}

void TGLabelEtch(UILabel *label) {
	label.shadowColor = [[TGTheme shared] etchedTextShadowColour];
	label.shadowOffset = TGMetricShadowOffsetEtched;
}
