//
// TGDevFileToolsViewController - generate a file through TDLib and watch it upload.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

static inline NSString *TGDevFileToolsProgressText(NSString *stage,
		float progress) {
	NSString *label = stage.length ? stage : TGLocalized(@"Working");
	return [NSString stringWithFormat:@"%@  %d%%", label,
			(int)(progress * 100)];
}

static inline NSArray *TGDevFileToolsResultModels(NSString *path,
		long long size, NSString *preview) {
	NSString *body = preview.length
			? [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "]
			: TGLocalized(@"Tap to read the first bytes back.");
	return @[
		@{@"title" : TGLocalized(@"Path"), @"detail" : path ?: @""},
		@{@"title" : TGLocalized(@"Size"),
		  @"detail" : [NSString stringWithFormat:@"%lld bytes", size]},
		@{@"title" : body},
	];
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGDevFileToolsViewController : TGRowsViewController

@end
#endif

// vim:ft=objc
