//
// TGTextStylesViewController - the manager for custom text composition
// styles. The list is Telegram's updateTextCompositionStyles; every row
// opens its examples through getTextCompositionStyleExample.
//
#ifndef TGTEXTSTYLESVIEWCONTROLLER_H
#define TGTEXTSTYLESVIEWCONTROLLER_H

#import <Foundation/Foundation.h>

/// The name a style row shows; official falls back to the short name when
/// the creator has not given it a title.
static inline NSString *TGTextStyleRowTitle(NSDictionary *style) {
	return style[@"title"] ?: style[@"name"] ?: @"Style";
}

/// The prompt under the name, or who owns a style without one.
static inline NSString *TGTextStyleRowDetail(NSDictionary *style) {
	NSString *prompt = style[@"prompt"];
	if (prompt.length)
		return prompt;
	return [style[@"isCreator"] boolValue] ? @"Created by you"
			: @"Telegram style";
}

static inline NSArray *TGTextStyleRowTitles(NSArray *styles) {
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *style in styles)
		[titles addObject:TGTextStyleRowTitle(style)];
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGTextStylesViewController : TGRowsViewController
@end
#endif

#endif // TGTEXTSTYLESVIEWCONTROLLER_H
