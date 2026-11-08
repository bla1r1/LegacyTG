#import "TGMediaPlayerView.h"

@implementation TGMediaPlayerView

- (void)setPlayerLayer:(AVPlayerLayer *)playerLayer {
	[_playerLayer removeFromSuperlayer];
	_playerLayer = playerLayer;
	if (playerLayer){
		playerLayer.frame = self.bounds;
		[self.layer addSublayer:playerLayer];
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.playerLayer.frame = self.bounds;
}

@end
