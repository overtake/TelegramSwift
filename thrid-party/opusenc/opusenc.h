#ifndef __OPUSENC_H
#define __OPUSENC_H

#include "opus_types.h"
#include <ogg/ogg.h>

#import "TGDataItem.h"

#ifdef ENABLE_NLS
#include <libintl.h>
#define _(X) gettext(X)
#else
#define _(X) (X)
#define textdomain(X)
#define bindtextdomain(X, Y)
#endif
#ifdef gettext_noop
#define N_(X) gettext_noop(X)
#else
#define N_(X) (X)
#endif

typedef struct
{
    void *readdata;
    opus_int64 total_samples_per_channel;
    int rawmode;
    int channels;
    long rate;
    int gain;
    int samplesize;
    int endianness;
    char *infilename;
    int ignorelength;
    int skip;
    int extraout;
    char *comments;
    int comments_length;
    int copy_comments;
} oe_enc_opt;

typedef struct
{
    int (*id_func)(unsigned char *buf, int len); /* Returns true if can load file */
    int id_data_len; /* Amount of data needed to id whether this can load the file */
    int (*open_func)(FILE *in, oe_enc_opt *opt, unsigned char *buf, int buflen);
    void (*close_func)(void *);
    char *format;
    char *description;
} input_format;

@interface TGOggOpusWriter : NSObject

- (bool)beginWithDataItem:(TGDataItem *)dataItem;
- (bool)writeFrame:(uint8_t *)framePcmBytes frameByteCount:(NSUInteger)frameByteCount;
- (NSUInteger)encodedBytes;
- (NSTimeInterval)encodedDuration;

@end

#endif /* __OPUSENC_H */
