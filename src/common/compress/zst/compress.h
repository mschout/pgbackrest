/***********************************************************************************************************************************
ZST Compress

Compress IO to the zst format.
***********************************************************************************************************************************/
#ifdef HAVE_LIBZST

#ifndef COMMON_COMPRESS_ZST_COMPRESS_H
#define COMMON_COMPRESS_ZST_COMPRESS_H

#include "common/io/filter/filter.h"

/***********************************************************************************************************************************
Filter type constant
***********************************************************************************************************************************/
#define ZST_COMPRESS_FILTER_TYPE                                    "zstCompress"
    STRING_DECLARE(ZST_COMPRESS_FILTER_TYPE_STR);

/***********************************************************************************************************************************
Constructors
***********************************************************************************************************************************/
IoFilter *zstCompressNew(int level);

#endif

#endif // HAVE_LIBZST
