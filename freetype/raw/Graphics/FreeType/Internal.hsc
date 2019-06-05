{-# language PatternSynonyms #-}
{-# language LambdaCase #-}
{-# language TemplateHaskell #-}
{-# language QuasiQuotes #-}
{-# language TypeFamilies #-}
{-# language RecordWildCards #-}
{-# language ViewPatterns #-}
{-# language TypeSynonymInstances #-}
{-# language FlexibleInstances #-}
{-# language FlexibleContexts #-}
{-# language StrictData #-}
{-# language ScopedTypeVariables #-}
{-# language OverloadedStrings #-}
{-# language ForeignFunctionInterface #-}
{-# language DeriveAnyClass #-}
{-# language DerivingStrategies #-}
{-# language GeneralizedNewtypeDeriving #-}
{-# language PolyKinds #-}
{-# language DataKinds #-}
{-# language UnboxedTuples #-}
{-# language CPP #-}
{-# options_ghc -Wno-missing-pattern-synonym-signatures #-}
{-# options_ghc -funbox-strict-fields #-}

-- |
-- Copyright :  (c) 2019 Edward Kmett
-- License   :  BSD-2-Clause OR Apache-2.0
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MODULE_H
#include FT_SYSTEM_H
#include FT_GLYPH_H
#include FT_TYPES_H
#include FT_TRIGONOMETRY_H
#include "ft.h"
#include "hsc-err.h"
#include "hsc-struct.h"
#let pattern n,t = "pattern %s :: %s\npattern %s = %s (%d)",#n,#t,#n,#t,(int)(FT_ ## n)

module Graphics.FreeType.Internal
(

  Angle
, pattern ANGLE_PI
, pattern ANGLE_2PI
, pattern ANGLE_PI2
, pattern ANGLE_PI4
, angleDiff

, BBox(..)

, Bitmap(..)
, BitmapGlyph
, BitmapGlyphRec(..)
, BitmapSize(..)

, Error
  ( Error
#err_exports
  )
, ok

, Face, FaceRec
, foreignFace

, Generic(..)

, Glyph, GlyphRec(..)

, GlyphBBoxMode
  ( GlyphBBoxMode
  , GLYPH_BBOX_UNSCALED
  , GLYPH_BBOX_SUBPIXELS
  , GLYPH_BBOX_GRIDFIT
  , GLYPH_BBOX_TRUNCATE
  , GLYPH_BBOX_PIXELS
  )
, GlyphClass
, GlyphFormat
  ( GlyphFormat
  , GLYPH_FORMAT_NONE
  , GLYPH_FORMAT_COMPOSITE
  , GLYPH_FORMAT_BITMAP
  , GLYPH_FORMAT_OUTLINE
  , GLYPH_FORMAT_PLOTTER
  )
, GlyphSlot
, GlyphSlotRec

, KerningMode
  ( KerningMode
  , KERNING_DEFAULT
  , KERNING_UNFITTED
  , KERNING_UNSCALED
  )
, Library, LibraryRec
, foreignLibrary
, pattern FREETYPE_MAJOR
, pattern FREETYPE_MINOR
, pattern FREETYPE_PATCH

, LoadFlags
  ( LoadFlags
  , LOAD_DEFAULT
  , LOAD_NO_SCALE
  , LOAD_NO_HINTING
  , LOAD_RENDER
  , LOAD_NO_BITMAP
  , LOAD_VERTICAL_LAYOUT
  , LOAD_FORCE_AUTOHINT
  , LOAD_CROP_BITMAP
  , LOAD_PEDANTIC
  , LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH
  , LOAD_NO_RECURSE
  , LOAD_IGNORE_TRANSFORM
  , LOAD_MONOCHROME
  , LOAD_LINEAR_DESIGN
  , LOAD_NO_AUTOHINT
  , LOAD_COLOR
  , LOAD_COMPUTE_METRICS
  , LOAD_BITMAP_METRICS_ONLY
  )

, Matrix(..)
, matrixInvert, matrixMultiply

, Memory
, MemoryRec(..)
, AllocFunc, FreeFunc, ReallocFunc


, Outline(..)
, OutlineFlags
  ( OutlineFlags
  , OUTLINE_NONE
  , OUTLINE_OWNER
  , OUTLINE_EVEN_ODD_FILL
  , OUTLINE_REVERSE_FILL
  , OUTLINE_IGNORE_DROPOUTS
  , OUTLINE_SMART_DROPOUTS
  , OUTLINE_INCLUDE_STUBS
  , OUTLINE_HIGH_PRECISION
  , OUTLINE_SINGLE_PASS
  )
, OutlineGlyph, OutlineGlyphRec(..)

, PixelMode
  ( PixelMode
  , PIXEL_MODE_NONE
  , PIXEL_MODE_MONO
  , PIXEL_MODE_GRAY
  , PIXEL_MODE_GRAY2
  , PIXEL_MODE_GRAY4
  , PIXEL_MODE_LCD
  , PIXEL_MODE_LCD_V
  , PIXEL_MODE_BGRA
  )

, Pos

, RenderMode
  ( RenderMode
  , RENDER_MODE_NORMAL
  , RENDER_MODE_LIGHT
  , RENDER_MODE_MONO
  , RENDER_MODE_LCD
  , RENDER_MODE_LCD_V
  )

, Size, SizeRec(..)
, SizeMetrics(..)
, SizeInternalRec

, SizeRequest, SizeRequestRec(..)
, SizeRequestType
  ( SizeRequestType
  , SIZE_REQUEST_TYPE_NOMINAL
  , SIZE_REQUEST_TYPE_REAL_DIM
  , SIZE_REQUEST_TYPE_BBOX
  , SIZE_REQUEST_TYPE_CELL
  , SIZE_REQUEST_TYPE_SCALES
  )

, Vector(..)
, vectorTransform

-- * contexts
, childPtr
, freeTypeCtx
) where

import Control.Exception
import Data.Bits
import Data.Default
import Data.Int
import qualified Data.Map as Map
import Data.Primitive.Types
import Data.Word
import Foreign.C.String
import Foreign.C.Types
import Foreign.ForeignPtr
import Foreign.ForeignPtr.Unsafe
import Foreign.Marshal.Unsafe
import Foreign.Marshal.Utils
import Foreign.Ptr
import Foreign.Storable
import Numeric.Fixed
import qualified Language.C.Inline as C
import qualified Language.C.Inline.Context as C
import qualified Language.C.Types as C
import Graphics.FreeType.Private

type Angle = Fixed
pattern ANGLE_PI  = Fixed (#const FT_ANGLE_PI)
pattern ANGLE_2PI = Fixed (#const FT_ANGLE_2PI)
pattern ANGLE_PI2 = Fixed (#const FT_ANGLE_PI2)
pattern ANGLE_PI4 = Fixed (#const FT_ANGLE_PI4)

type Glyph = ForeignPtr GlyphRec
type BitmapGlyph = ForeignPtr BitmapGlyphRec
type OutlineGlyph = ForeignPtr OutlineGlyphRec

#struct bbox,BBox,FT_BBox,xMin,Pos,yMin,Pos,xMax,Pos,yMax,Pos
#struct bitmap,Bitmap,FT_Bitmap,rows,Word32,width,Word32,pitch,Int32,buffer,Ptr Word8,num_grays,Word16,pixel_mode,Word8,palette_mode,Word8,palette,Ptr()
#struct _bitmapglyph,BitmapGlyphRec,FT_BitmapGlyphRec,root,GlyphRec,left,Int32,top,Int32,bitmap,Bitmap
#struct bitmapsize,BitmapSize,FT_Bitmap_Size,height,Int16,width,Int16,size,Pos,x_ppem,Pos,y_ppem,Pos
#struct generic,Generic,FT_Generic,data,Ptr (),finalizer,FinalizerPtr ()
#struct glyph,GlyphRec,FT_GlyphRec,library,Ptr Library,clazz,Ptr GlyphClass,format,GlyphFormat,advance,Vector
#struct matrix,Matrix,FT_Matrix,xx,Fixed,xy,Fixed,yx,Fixed,yy,Fixed
#struct memory,MemoryRec,struct FT_MemoryRec_,user,Ptr(),alloc,FunPtr AllocFunc,free,FunPtr FreeFunc,realloc,FunPtr ReallocFunc
#struct outline,Outline,FT_Outline,n_contours,Word16,n_points,Word16,points,Ptr Vector,tags,Ptr Word8,contours,Ptr Word16,flags,Int32
#struct _outlineglyph,OutlineGlyphRec,FT_OutlineGlyphRec, root,GlyphRec,outline,Outline
#struct sizemetrics,SizeMetrics,FT_Size_Metrics,x_ppem,Word16,y_ppem,Word16,x_scale,Fixed,y_scale,Fixed,ascender,Pos,descender,Pos,height,Pos,max_advance,Pos
#struct size,SizeRec,FT_SizeRec,face,Ptr FaceRec,generic,Generic,metrics,SizeMetrics,internal,Ptr SizeInternalRec
#struct sizerequest,SizeRequestRec,FT_Size_RequestRec,type,SizeRequestType,width,Int32,height,Int32,horiResolution,Word32,vertResolution,Word32
#struct vector,Vector,FT_Vector,x,Pos,y,Pos

-- | Given a foreign ptr and a ptr, produces a foreign ptr that has the same finalizers as the first, but now
-- pointing at the target value. Holding this foreign ptr will keep the original alive and vice versa.
--
-- This can be used when accessing, say, a part of a whole that has a shared lifetime.
childPtr :: ForeignPtr a -> Ptr b -> ForeignPtr b
childPtr fp p = fp `plusForeignPtr` minusPtr p (unsafeForeignPtrToPtr fp)

-- | By convention the library will throw any non-0 FT_Error encountered.
newtype Error = Error CInt deriving newtype (Eq,Ord,Show,Storable)

#err_patterns

foreign import ccall unsafe "ft.h" hs_get_error_string :: Error -> CString

instance Exception Error where
  displayException = unsafeLocalState . peekCString . hs_get_error_string

-- | Ensure that the 'Error' is ok, otherwise throw it.
ok :: Error -> IO ()
ok Err_Ok = return ()
ok e = throwIO e

type Face = ForeignPtr FaceRec
data FaceRec

pattern FREETYPE_MAJOR = (#const FREETYPE_MAJOR) :: Int
pattern FREETYPE_MINOR = (#const FREETYPE_MINOR) :: Int
pattern FREETYPE_PATCH = (#const FREETYPE_PATCH) :: Int

type GlyphSlot = ForeignPtr GlyphSlotRec
data GlyphSlotRec

-- Note: the library inconsistently passes these as an FT_UInt to FT_Get_Kerning
-- but the type itself is an int
newtype KerningMode = KerningMode Word32 deriving (Eq,Ord,Show)

#pattern KERNING_DEFAULT, KerningMode
#pattern KERNING_UNFITTED, KerningMode
#pattern KERNING_UNSCALED, KerningMode

data GlyphClass
newtype GlyphFormat = GlyphFormat Int32
  deriving Show
  deriving newtype (Eq,Ord,Storable)

#pattern GLYPH_FORMAT_NONE, GlyphFormat
#pattern GLYPH_FORMAT_COMPOSITE, GlyphFormat
#pattern GLYPH_FORMAT_BITMAP, GlyphFormat
#pattern GLYPH_FORMAT_OUTLINE, GlyphFormat
#pattern GLYPH_FORMAT_PLOTTER, GlyphFormat

type Library = ForeignPtr LibraryRec
data LibraryRec

type AllocFunc = Memory -> CLong -> IO (Ptr ())
type FreeFunc = Memory -> Ptr () -> IO ()
type ReallocFunc = Memory -> CLong -> CLong -> Ptr () -> IO (Ptr ())

type Memory = ForeignPtr MemoryRec


data SizeInternalRec
type Size = ForeignPtr SizeRec

type Pos = Int32

newtype SizeRequestType = SizeRequestType Int32 deriving newtype (Eq,Show,Storable,Prim)

#pattern SIZE_REQUEST_TYPE_NOMINAL, SizeRequestType
#pattern SIZE_REQUEST_TYPE_REAL_DIM, SizeRequestType
#pattern SIZE_REQUEST_TYPE_BBOX, SizeRequestType
#pattern SIZE_REQUEST_TYPE_CELL, SizeRequestType
#pattern SIZE_REQUEST_TYPE_SCALES, SizeRequestType

newtype LoadFlags = LoadFlags Int32 deriving newtype (Eq,Show,Storable,Prim,Bits)
#pattern LOAD_DEFAULT, LoadFlags
#pattern LOAD_NO_SCALE, LoadFlags
#pattern LOAD_NO_HINTING, LoadFlags
#pattern LOAD_RENDER, LoadFlags
#pattern LOAD_NO_BITMAP, LoadFlags
#pattern LOAD_VERTICAL_LAYOUT, LoadFlags
#pattern LOAD_FORCE_AUTOHINT, LoadFlags
#pattern LOAD_CROP_BITMAP, LoadFlags
#pattern LOAD_PEDANTIC, LoadFlags
#pattern LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH, LoadFlags
#pattern LOAD_NO_RECURSE, LoadFlags
#pattern LOAD_IGNORE_TRANSFORM, LoadFlags
#pattern LOAD_MONOCHROME, LoadFlags
#pattern LOAD_LINEAR_DESIGN, LoadFlags
#pattern LOAD_NO_AUTOHINT, LoadFlags
#pattern LOAD_COLOR, LoadFlags
#pattern LOAD_COMPUTE_METRICS, LoadFlags
#pattern LOAD_BITMAP_METRICS_ONLY, LoadFlags
instance Default LoadFlags where def = LOAD_DEFAULT

newtype OutlineFlags = OutlineFlags Int32 deriving newtype (Eq,Show,Storable,Prim,Bits)
#pattern OUTLINE_NONE, OutlineFlags
#pattern OUTLINE_OWNER, OutlineFlags
#pattern OUTLINE_EVEN_ODD_FILL, OutlineFlags
#pattern OUTLINE_REVERSE_FILL, OutlineFlags
#pattern OUTLINE_IGNORE_DROPOUTS, OutlineFlags
#pattern OUTLINE_SMART_DROPOUTS, OutlineFlags
#pattern OUTLINE_INCLUDE_STUBS, OutlineFlags
#pattern OUTLINE_HIGH_PRECISION, OutlineFlags
#pattern OUTLINE_SINGLE_PASS, OutlineFlags

newtype RenderMode = RenderMode Int32 deriving newtype (Eq,Show,Storable,Prim)
#pattern RENDER_MODE_NORMAL, RenderMode
#pattern RENDER_MODE_LIGHT, RenderMode
#pattern RENDER_MODE_MONO, RenderMode
#pattern RENDER_MODE_LCD, RenderMode
#pattern RENDER_MODE_LCD_V, RenderMode
instance Default RenderMode where def = RENDER_MODE_NORMAL

newtype PixelMode = PixelMode Int32 deriving newtype (Eq,Show,Storable,Prim)
#pattern PIXEL_MODE_NONE, PixelMode
#pattern PIXEL_MODE_MONO, PixelMode
#pattern PIXEL_MODE_GRAY, PixelMode
#pattern PIXEL_MODE_GRAY2, PixelMode
#pattern PIXEL_MODE_GRAY4, PixelMode
#pattern PIXEL_MODE_LCD, PixelMode
#pattern PIXEL_MODE_LCD_V, PixelMode
#pattern PIXEL_MODE_BGRA, PixelMode

-- inconsistently used as signed and unsigned in the library, choosing
newtype GlyphBBoxMode = GlyphBBoxMode Word32 deriving newtype (Eq,Show,Storable,Prim)
#pattern GLYPH_BBOX_UNSCALED, GlyphBBoxMode
#pattern GLYPH_BBOX_SUBPIXELS, GlyphBBoxMode
#pattern GLYPH_BBOX_GRIDFIT, GlyphBBoxMode
#pattern GLYPH_BBOX_TRUNCATE, GlyphBBoxMode
#pattern GLYPH_BBOX_PIXELS, GlyphBBoxMode

type SizeRequest = Ptr SizeRequestRec


C.context $ C.baseCtx <> mempty
  { C.ctxTypesTable = Map.fromList
    [ (C.TypeName "FT_Angle", [t|Fixed|])
    , (C.TypeName "FT_Error", [t|Error|])
    , (C.TypeName "FT_Face", [t|Ptr FaceRec|])
    , (C.TypeName "FT_Fixed", [t|Fixed|])
    , (C.TypeName "FT_Library", [t|Ptr LibraryRec|])
    , (C.TypeName "FT_Matrix", [t|Matrix|])
    , (C.TypeName "FT_Vector", [t|Vector|])
    ]
  }

C.include "<ft2build.h>"
C.verbatim "#include FT_FREETYPE_H"
C.verbatim "#include FT_GLYPH_H"
C.verbatim "#include FT_MODULE_H"
C.verbatim "#include FT_TYPES_H"
C.verbatim "#include FT_TRIGONOMETRY_H"

angleDiff :: Angle -> Angle -> Angle
angleDiff angle1 angle2 = [C.pure|FT_Angle { FT_Angle_Diff($(FT_Angle angle1),$(FT_Angle angle2)) }|]

matrixInvert:: Matrix -> Maybe Matrix
matrixInvert m = unsafeLocalState $
  with m $ \mm -> do
    e <- [C.exp|FT_Error { FT_Matrix_Invert($(FT_Matrix * mm))}|]
    if e == Err_Ok then Just <$> peek mm else pure Nothing

matrixMultiply :: Matrix -> Matrix -> Matrix
matrixMultiply m n = unsafeLocalState $
   with m $ \mm ->
   with n $ \nm ->
    [C.block|void {
      FT_Matrix_Multiply($(FT_Matrix * mm),$(FT_Matrix * nm));
    }|] *> peek nm

instance Semigroup Matrix where
  (<>) = matrixMultiply

instance Monoid Matrix where
  mempty = Matrix 1 0 0 1

instance Default Matrix where
  def = Matrix 1 0 0 1

vectorTransform :: Vector -> Matrix -> Vector
vectorTransform v m = unsafeLocalState $
  with v $ \vp ->
    with m $ \mp ->
      [C.block|void { FT_Vector_Transform($(FT_Vector * vp),$(FT_Matrix * mp)); }|] *> peek vp

instance Default Vector where
  def = Vector 0 0

foreignFace :: Ptr FaceRec -> IO Face
foreignFace = newForeignPtr [C.funPtr| void free_face(FT_Face f) { FT_Done_Face(f); } |]

foreignLibrary :: Ptr LibraryRec -> IO Library
foreignLibrary = newForeignPtr [C.funPtr| void free_library(FT_Library l) { FT_Done_Library(l); }|]

freeTypeCtx :: C.Context
freeTypeCtx = mempty
  { C.ctxTypesTable = Map.fromList
    [ (C.TypeName "FT_BBox",               [t|BBox|])
    , (C.TypeName "FT_Bitmap",             [t|Bitmap|])
    , (C.TypeName "FT_BitmapGlyph",        [t|Ptr BitmapGlyphRec|])
    , (C.TypeName "FT_BitmapGlyphRec",     [t|BitmapGlyphRec|])
    , (C.Struct   "FT_BitmapGlyphRec",     [t|BitmapGlyphRec|])
    , (C.TypeName "FT_Bool",               [t|Word8|])
    , (C.TypeName "FT_Error",              [t|Error|])
    , (C.TypeName "FT_Face",               [t|Ptr FaceRec|])
    , (C.TypeName "FT_FaceRec_",           [t|FaceRec|])
    , (C.TypeName "FT_Generic",            [t|Generic|])
    , (C.TypeName "FT_Generic_Finalizer",  [t|FinalizerPtr ()|])
    , (C.TypeName "FT_Glyph",              [t|Ptr GlyphRec|])
    , (C.TypeName "FT_GlyphRec",           [t|GlyphRec|])
    , (C.Struct   "FT_GlyphRec_",          [t|GlyphRec|])
    , (C.TypeName "FT_Glyph_Format",       [t|GlyphFormat|])
    , (C.Enum     "FT_Glyph_Format_",      [t|GlyphFormat|])
    , (C.TypeName "FT_GlyphSlot",          [t|Ptr GlyphSlotRec|])
    , (C.TypeName "FT_GlyphSlotRec",       [t|GlyphSlotRec|])
    , (C.Struct   "FT_GlyphSlotRec_",      [t|GlyphSlotRec|])
    , (C.TypeName "FT_Int",                [t|Int32|])
    , (C.TypeName "FT_Int32",              [t|Int32|])
    , (C.TypeName "FT_KerningMode",        [t|KerningMode|])
    , (C.Enum     "FT_KerningMode_",       [t|KerningMode|])
    , (C.TypeName "FT_Library",            [t|Ptr LibraryRec|])
    , (C.TypeName "FT_LibraryRec_",        [t|LibraryRec|])
    , (C.TypeName "FT_Long",               [t|Int32|])
    , (C.TypeName "FT_Matrix",             [t|Matrix|])
    , (C.Struct   "FT_Matrix_",            [t|Matrix|])
    , (C.TypeName "FT_Memory",             [t|Ptr MemoryRec|])
    , (C.TypeName "FT_MemoryRec_",         [t|MemoryRec|])
    , (C.TypeName "FT_Outline",            [t|Outline|])
    , (C.TypeName "FT_OutlineGlyph",       [t|Ptr OutlineGlyphRec|])
    , (C.TypeName "FT_OutlineGlyphRec",    [t|OutlineGlyphRec|])
    , (C.Struct   "FT_OutlineGlyphRec",    [t|OutlineGlyphRec|])
    , (C.TypeName "FT_Render_Mode",        [t|RenderMode|])
    , (C.Enum     "FT_Render_Mode_",       [t|RenderMode|])
    , (C.TypeName "FT_Size_Internal",      [t|Ptr SizeInternalRec|])
    , (C.Struct   "FT_Size_InternalRec_",  [t|SizeInternalRec|])
    , (C.TypeName "FT_Size_Metrics",       [t|SizeMetrics|])
    , (C.Struct   "FT_Size_Metrics_",      [t|SizeMetrics|])
    , (C.TypeName "FT_Size_Rec",           [t|SizeRec|])
    , (C.Struct   "FT_Size_Rec_",          [t|SizeRec|])
    , (C.Struct   "FT_Size_Request",       [t|Ptr SizeRequestRec|])
    , (C.Struct   "FT_Size_RequestRec_",   [t|SizeRequestRec|])
    , (C.TypeName "FT_Size_RequestRec",    [t|SizeRequestRec|])
    , (C.TypeName "FT_Size_Request_Type",  [t|SizeRequestType|])
    , (C.Enum     "FT_Size_Request_Type_", [t|SizeRequestType|])
    , (C.Struct   "FT_Size_Rec_",          [t|SizeRec|])
    , (C.TypeName "FT_UInt",               [t|Word32|])
    , (C.TypeName "FT_UInt32",             [t|Word32|])
    , (C.TypeName "FT_ULong",              [t|Word32|])
    , (C.TypeName "FT_Vector",             [t|Vector|])
    , (C.Struct   "FT_Vector_",            [t|Vector|])
    ]
  , C.ctxAntiQuoters = Map.fromList
    [ ("ustr",         anti (C.Ptr [C.CONST] $ C.TypeSpecifier mempty (C.Char (Just C.Unsigned))) [t|Ptr CUChar|] [|withCUString|])
    , ("str",          anti (C.Ptr [C.CONST] $ C.TypeSpecifier mempty (C.Char Nothing)) [t|Ptr CChar|] [|withCString|])
    , ("bbox",         anti (ptr $ C.TypeName "FT_BBox") [t|Ptr BBox|] [|with|])
    , ("bitmapglyph",  anti (C.TypeSpecifier mempty $ C.TypeName "FT_BitmapGlyph") [t|Ptr BitmapGlyph|] [|withForeignPtr|])
    , ("face",         anti (C.TypeSpecifier mempty $ C.TypeName "FT_Face") [t|Ptr FaceRec|] [|withForeignPtr|])
    , ("glyph",        anti (C.TypeSpecifier mempty $ C.TypeName "FT_Glyph") [t|Ptr Glyph|] [|withForeignPtr|])
    , ("glyph-slot",   anti (C.TypeSpecifier mempty $ C.TypeName "FT_GlyphSlot") [t|Ptr GlyphSlotRec|] [|withForeignPtr|])
    , ("generic",      anti (ptr $ C.TypeName "FT_Generic") [t|Ptr Generic|] [|with|])
    , ("library",      anti (C.TypeSpecifier mempty $ C.TypeName "FT_Library") [t|Ptr LibraryRec|] [|withForeignPtr|])
    , ("matrix",       anti (ptr $ C.TypeName "FT_Matrix") [t|Ptr Matrix|] [|with|])
    , ("outlineglyph", anti (C.TypeSpecifier mempty $ C.TypeName "FT_OutlineGlyph") [t|Ptr OutlineGlyph|] [|withForeignPtr|])
    , ("vector",       anti (ptr $ C.TypeName "FT_Vector") [t|Ptr Vector|] [|with|])
    ]
  } where ptr = C.Ptr [] . C.TypeSpecifier mempty
