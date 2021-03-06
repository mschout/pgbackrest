/***********************************************************************************************************************************
BZ2 Decompress

Decompress IO from the bz2 format.
***********************************************************************************************************************************/
#ifndef COMMON_COMPRESS_BZ2_DECOMPRESS_H
#define COMMON_COMPRESS_BZ2_DECOMPRESS_H

#include "common/io/filter/filter.h"

/***********************************************************************************************************************************
Filter type constant
***********************************************************************************************************************************/
#define BZ2_DECOMPRESS_FILTER_TYPE                                   "bz2Decompress"
    STRING_DECLARE(BZ2_DECOMPRESS_FILTER_TYPE_STR);

/***********************************************************************************************************************************
Constructors
***********************************************************************************************************************************/
IoFilter *bz2DecompressNew(void);

#endif
