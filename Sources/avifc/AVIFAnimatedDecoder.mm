//
//  AVIFAnimatedDecoder.m
//  
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
//

#import "AVIFAnimatedDecoder.h"
#import "avif/avif.h"
#import <Accelerate/Accelerate.h>
#import "AVIFRGBAMultiplier.h"
#import "PlatformImage.h"
#import "AVIFImageXForm.h"
#import <thread>

@implementation AVIFAnimatedDecoder {
    avifDecoder *_idec;
}

-(nullable id)initWithData:(nonnull NSData*)data {
    _idec = avifDecoderCreate();

    avifDecoderSetIOMemory(_idec, reinterpret_cast<const uint8_t*>(data.bytes), data.length);
    CGFloat scale = 1;
    
    _idec->strictFlags = AVIF_STRICT_DISABLED;
    _idec->ignoreXMP = true;
    _idec->ignoreExif = true;
    _idec->maxThreads = std::thread::hardware_concurrency();
    avifResult decodeResult = avifDecoderParse(_idec);
    if (decodeResult != AVIF_RESULT_OK) {
        avifDecoderDestroy(_idec);
        return nil;
    }
    return self;
}

-(nullable Image*)getImage:(int)frame {
    CGImageRef ref = [self get:frame];
    if (!ref) return NULL;
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:ref size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:ref scale:1 orientation:UIImageOrientationUp];
#endif
    return image;
}

-(nullable CGImageRef)get:(int)frame {
    avifResult nextImageResult = avifDecoderNthImage(_idec, frame);
    if (nextImageResult != AVIF_RESULT_OK) {
        return nil;
    }
    auto xForm = [[AVIFImageXForm alloc] init];
    return [xForm formCGImage:_idec scale:1];
}

-(int)frameDuration:(int)frame {
    avifImageTiming timing;
    avifDecoderNthImageTiming(_idec, frame, &timing);
    return (int)(1000.0f / ((float)timing.timescale) * (float)timing.durationInTimescales);
}

-(int)framesCount {
    return _idec->imageCount;
}

-(int)duration {
    return (int)(1000.0f / ((float)_idec->timescale) * (float)_idec->durationInTimescales);
}

-(CGSize)imageSize {
    return CGSizeMake(_idec->image->width, _idec->image->height);
}

- (void)dealloc {
    if (_idec) {
        avifDecoderDestroy(_idec);
        _idec = NULL;
    }
}

@end
