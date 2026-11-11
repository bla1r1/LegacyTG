//
// TGClient+Affiliate.m
//
// Telegram pays affiliates through Fragment. This build has no wallet and
// cannot withdraw, but the program records are ordinary TDLib reads and
// writes: the catalogue, the connection and a channel's own parameters. The
// screen prints Telegram's answer, including a refusal on an account that
// owns neither a bot nor a channel.
//
#import "TGClient+Affiliate.h"
#import "TGClientInternal.h"

static NSDictionary *TGAFFDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSNumber *TGAFFNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @0;
}

static NSDictionary *TGAFFStarAmount(NSDictionary *amount) {
	return @{
		@"starCount" : TGAFFNumber(amount[@"star_count"]),
		@"nanostarCount" : TGAFFNumber(amount[@"nanostar_count"]),
	};
}

@implementation TGClient (Affiliate)

@end

// vim:ft=objc
