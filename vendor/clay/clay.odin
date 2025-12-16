// VERSION: 0.14

/*
    NOTE: In order to use this library you must define
    the following macro in exactly one file, _before_ including clay.h:

    #define CLAY_IMPLEMENTATION
    #include "clay.h"

    See the examples folder for details.
*/
package src

import "core:c"
import "core:strings"

when ODIN_OS == .Windows {
	foreign import Clay "lib/clay.lib"
} else when ODIN_OS == .Linux {
	foreign import Clay "lib/clay.a"
}

// Note: String is not guaranteed to be null terminated. It may be if created from a literal C string,
// but it is also used to represent slices.
String :: struct {
	// Set this boolean to true if the char* data underlying this string will live for the entire lifetime of the program.
	// This will automatically be set for strings created with CLAY_STRING, as the macro requires a string literal.
	isStaticallyAllocated: i32,
	length:                i32,

	// The underlying character memory. Note: this will not be copied and will not extend the lifetime of the underlying memory.
	chars:                 cstring,
}

// StringSlice is used to represent non owning string slices, and includes
// a baseChars field which points to the string this slice is derived from.
StringSlice :: struct {
	length:    i32,
	chars:     cstring,
	baseChars: cstring, // The source string / char* that this slice was derived from
}

Context :: struct {}

// Arena is a memory arena structure that is used by clay to manage its internal allocations.
// Rather than creating it by hand, it's easier to use CreateArenaWithCapacityAndMemory()
Arena :: struct {
	nextAllocation: c.uintptr_t,
	capacity:       i32,
	memory:         cstring,
}

Dimensions :: struct {
	width, height: f32,
}

Vector2 :: struct {
	x, y: f32,
}

// Internally clay conventionally represents colors as 0-255, but interpretation is up to the renderer.
Color :: struct {
	r, g, b, a: f32,
}

BoundingBox :: struct {
	x, y, width, height: f32,
}

// Primarily created via the CLAY_ID(), CLAY_IDI(), CLAY_ID_LOCAL() and CLAY_IDI_LOCAL() macros.
// Represents a hashed string ID used for identifying and finding specific clay UI elements, required
// by functions such as PointerOver() and GetElementData().
ElementId :: struct {
	id:       u32, // The resulting hash generated from the other fields.
	offset:   u32, // A numerical offset applied after computing the hash from stringId.
	baseId:   u32, // A base hash value to start from, for example the parent element ID is used when calculating CLAY_ID_LOCAL().
	stringId: String, // The string id to hash.
}

// A sized array of ElementId.
ElementIdArray :: struct {
	capacity:      i32,
	length:        i32,
	internalArray: ^ElementId,
}

// Controls the "radius", or corner rounding of elements, including rectangles, borders and images.
// The rounding is determined by drawing a circle inset into the element corner by (radius, radius) pixels.
CornerRadius :: struct {
	topLeft:     f32,
	topRight:    f32,
	bottomLeft:  f32,
	bottomRight: f32,
}

// Controls the direction in which child elements will be automatically laid out.
LayoutDirection :: enum u8 {
	// Element Configs ---------------------------

	// Controls the direction in which child elements will be automatically laid out.
	// packed             = -1,

	// (Default) Lays out child elements from left to right with increasing x.
	LEFT_TO_RIGHT = 0,

	// Lays out child elements from top to bottom with increasing y.
	TOP_TO_BOTTOM = 1,
}

// Controls the alignment along the x axis (horizontal) of child elements.
LayoutAlignmentX :: enum u8 {
	// Controls the alignment along the x axis (horizontal) of child elements.
	// packed              = -1,

	// (Default) Aligns child elements to the left hand side of this element, offset by padding.width.left
	ALIGN_X_LEFT   = 0,

	// Aligns child elements to the right hand side of this element, offset by padding.width.right
	ALIGN_X_RIGHT  = 1,

	// Aligns child elements horizontally to the center of this element
	ALIGN_X_CENTER = 2,
}

// Controls the alignment along the y axis (vertical) of child elements.
LayoutAlignmentY :: enum u8 {
	// Controls the alignment along the y axis (vertical) of child elements.
	// packed              = -1,

	// (Default) Aligns child elements to the top of this element, offset by padding.width.top
	ALIGN_Y_TOP    = 0,

	// Aligns child elements to the bottom of this element, offset by padding.width.bottom
	ALIGN_Y_BOTTOM = 1,

	// Aligns child elements vertically to the center of this element
	ALIGN_Y_CENTER = 2,
}

// Controls how the element takes up space inside its parent container.
SizingType :: enum u8 {
	// Controls how the element takes up space inside its parent container.
	// packed                    = -1,

	// (default) Wraps tightly to the size of the element's contents.
	SIZING_TYPE_FIT     = 0,

	// Expands along this axis to fill available space in the parent element, sharing it with other GROW elements.
	SIZING_TYPE_GROW    = 1,

	// Expects 0-1 range. Clamps the axis size to a percent of the parent container's axis size minus padding and child gaps.
	SIZING_TYPE_PERCENT = 2,

	// Clamps the axis size to an exact size in pixels.
	SIZING_TYPE_FIXED   = 3,
}

// Controls how child elements are aligned on each axis.
ChildAlignment :: struct {
	x: LayoutAlignmentX, // Controls alignment of children along the x axis.
	y: LayoutAlignmentY, // Controls alignment of children along the y axis.
}

// Controls the minimum and maximum size in pixels that this element is allowed to grow or shrink to,
// overriding sizing types such as FIT or GROW.
SizingMinMax :: struct {
	min: f32, // The smallest final size of the element on this axis will be this value in pixels.
	max: f32, // The largest final size of the element on this axis will be this value in pixels.
}

// Controls the sizing of this element along one axis inside its parent container.
SizingAxis :: struct {
	size: struct #raw_union {
		minMax:  SizingMinMax, // Controls the minimum and maximum size in pixels that this element is allowed to grow or shrink to, overriding sizing types such as FIT or GROW.
		percent: f32, // Expects 0-1 range. Clamps the axis size to a percent of the parent container's axis size minus padding and child gaps.
	},
	type: SizingType, // Controls how the element takes up space inside its parent container.
}

// Controls the sizing of this element along one axis inside its parent container.
Sizing :: struct {
	width:  SizingAxis, // Controls the width sizing of the element, along the x axis.
	height: SizingAxis, // Controls the height sizing of the element, along the y axis.
}

// Controls "padding" in pixels, which is a gap between the bounding box of this element and where its children
// will be placed.
Padding :: struct {
	left:   u16,
	right:  u16,
	top:    u16,
	bottom: u16,
}

PaddingWrapper :: struct {
	wrapped: Padding,
}

// Controls various settings that affect the size and position of an element, as well as the sizes and positions
// of any child elements.
LayoutConfig :: struct {
	sizing:          Sizing, // Controls the sizing of this element inside it's parent container, including FIT, GROW, PERCENT and FIXED sizing.
	padding:         Padding, // Controls "padding" in pixels, which is a gap between the bounding box of this element and where its children will be placed.
	childGap:        u16, // Controls the gap in pixels between child elements along the layout axis (horizontal gap for LEFT_TO_RIGHT, vertical gap for TOP_TO_BOTTOM).
	childAlignment:  ChildAlignment, // Controls how child elements are aligned on each axis.
	layoutDirection: LayoutDirection, // Controls the direction in which child elements will be automatically laid out.
}

LayoutConfigWrapper :: struct {
	wrapped: LayoutConfig,
}

// Controls how text "wraps", that is how it is broken into multiple lines when there is insufficient horizontal space.
TextElementConfigWrapMode :: enum u8 {
	// Controls how text "wraps", that is how it is broken into multiple lines when there is insufficient horizontal space.
	// packed                  = -1,

	// (default) breaks on whitespace characters.
	TEXT_WRAP_WORDS    = 0,

	// Don't break on space characters, only on newlines.
	TEXT_WRAP_NEWLINES = 1,

	// Disable text wrapping entirely.
	TEXT_WRAP_NONE     = 2,
}

// Controls how wrapped lines of text are horizontally aligned within the outer text bounding box.
TextAlignment :: enum u8 {
	// Controls how wrapped lines of text are horizontally aligned within the outer text bounding box.
	// packed                 = -1,

	// (default) Horizontally aligns wrapped lines of text to the left hand side of their bounding box.
	TEXT_ALIGN_LEFT   = 0,

	// Horizontally aligns wrapped lines of text to the center of their bounding box.
	TEXT_ALIGN_CENTER = 1,

	// Horizontally aligns wrapped lines of text to the right hand side of their bounding box.
	TEXT_ALIGN_RIGHT  = 2,
}

// Controls various functionality related to text elements.
TextElementConfig :: struct {
	// A pointer that will be transparently passed through to the resulting render command.
	userData:      rawptr,

	// The RGBA color of the font to render, conventionally specified as 0-255.
	textColor:     Color,

	// An integer transparently passed to MeasureText to identify the font to use.
	// The debug view will pass fontId = 0 for its internal text.
	fontId:        u16,

	// Controls the size of the font. Handled by the function provided to MeasureText.
	fontSize:      u16,

	// Controls extra horizontal spacing between characters. Handled by the function provided to MeasureText.
	letterSpacing: u16,

	// Controls additional vertical space between wrapped lines of text.
	lineHeight:    u16,

	// Controls how text "wraps", that is how it is broken into multiple lines when there is insufficient horizontal space.
	// CLAY_TEXT_WRAP_WORDS (default) breaks on whitespace characters.
	// CLAY_TEXT_WRAP_NEWLINES doesn't break on space characters, only on newlines.
	// CLAY_TEXT_WRAP_NONE disables wrapping entirely.
	wrapMode:      TextElementConfigWrapMode,

	// Controls how wrapped lines of text are horizontally aligned within the outer text bounding box.
	// CLAY_TEXT_ALIGN_LEFT (default) - Horizontally aligns wrapped lines of text to the left hand side of their bounding box.
	// CLAY_TEXT_ALIGN_CENTER - Horizontally aligns wrapped lines of text to the center of their bounding box.
	// CLAY_TEXT_ALIGN_RIGHT - Horizontally aligns wrapped lines of text to the right hand side of their bounding box.
	textAlignment: TextAlignment,
}

TextElementConfigWrapper :: struct {
	wrapped: TextElementConfig,
}

// Controls various settings related to aspect ratio scaling element.
AspectRatioElementConfig :: struct {
	aspectRatio: f32, // A float representing the target "Aspect ratio" for an element, which is its final width divided by its final height.
}

AspectRatioElementConfigWrapper :: struct {
	wrapped: AspectRatioElementConfig,
}

// Controls various settings related to image elements.
ImageElementConfig :: struct {
	imageData: rawptr, // A transparent pointer used to pass image data through to the renderer.
}

ImageElementConfigWrapper :: struct {
	wrapped: ImageElementConfig,
}

// Controls where a floating element is offset relative to its parent element.
// Note: see https://github.com/user-attachments/assets/b8c6dfaa-c1b1-41a4-be55-013473e4a6ce for a visual explanation.
FloatingAttachPointType :: enum u8 {
	// packed                          = -1,
	ATTACH_POINT_LEFT_TOP      = 0,
	ATTACH_POINT_LEFT_CENTER   = 1,
	ATTACH_POINT_LEFT_BOTTOM   = 2,
	ATTACH_POINT_CENTER_TOP    = 3,
	ATTACH_POINT_CENTER_CENTER = 4,
	ATTACH_POINT_CENTER_BOTTOM = 5,
	ATTACH_POINT_RIGHT_TOP     = 6,
	ATTACH_POINT_RIGHT_CENTER  = 7,
	ATTACH_POINT_RIGHT_BOTTOM  = 8,
}

// Controls where a floating element is offset relative to its parent element.
FloatingAttachPoints :: struct {
	element: FloatingAttachPointType, // Controls the origin point on a floating element that attaches to its parent.
	parent:  FloatingAttachPointType, // Controls the origin point on the parent element that the floating element attaches to.
}

// Controls how mouse pointer events like hover and click are captured or passed through to elements underneath a floating element.
PointerCaptureMode :: enum u8 {
	// Controls how mouse pointer events like hover and click are captured or passed through to elements underneath a floating element.
	// packed                                = -1,

	// (default) "Capture" the pointer event and don't allow events like hover and click to pass through to elements underneath.
	POINTER_CAPTURE_MODE_CAPTURE     = 0,

	//    CLAY_POINTER_CAPTURE_MODE_PARENT, TODO pass pointer through to attached parent

	// Transparently pass through pointer events like hover and click to elements underneath the floating element.
	POINTER_CAPTURE_MODE_PASSTHROUGH = 1,
}

// Controls which element a floating element is "attached" to (i.e. relative offset from).
FloatingAttachToElement :: enum u8 {
	// Controls which element a floating element is "attached" to (i.e. relative offset from).
	// packed                         = -1,

	// (default) Disables floating for this element.
	ATTACH_TO_NONE            = 0,

	// Attaches this floating element to its parent, positioned based on the .attachPoints and .offset fields.
	ATTACH_TO_PARENT          = 1,

	// Attaches this floating element to an element with a specific ID, specified with the .parentId field. positioned based on the .attachPoints and .offset fields.
	ATTACH_TO_ELEMENT_WITH_ID = 2,

	// Attaches this floating element to the root of the layout, which combined with the .offset field provides functionality similar to "absolute positioning".
	ATTACH_TO_ROOT            = 3,
}

// Controls whether or not a floating element is clipped to the same clipping rectangle as the element it's attached to.
FloatingClipToElement :: enum u8 {
	// Controls whether or not a floating element is clipped to the same clipping rectangle as the element it's attached to.
	// packed                       = -1,

	// (default) - The floating element does not inherit clipping.
	CLIP_TO_NONE            = 0,

	// The floating element is clipped to the same clipping rectangle as the element it's attached to.
	CLIP_TO_ATTACHED_PARENT = 1,
}

// Controls various settings related to "floating" elements, which are elements that "float" above other elements, potentially overlapping their boundaries,
// and not affecting the layout of sibling or parent elements.
FloatingElementConfig :: struct {
	// Offsets this floating element by the provided x,y coordinates from its attachPoints.
	offset:             Vector2,

	// Expands the boundaries of the outer floating element without affecting its children.
	expand:             Dimensions,

	// When used in conjunction with .attachTo = CLAY_ATTACH_TO_ELEMENT_WITH_ID, attaches this floating element to the element in the hierarchy with the provided ID.
	// Hint: attach the ID to the other element with .id = CLAY_ID("yourId"), and specify the id the same way, with .parentId = CLAY_ID("yourId").id
	parentId:           u32,

	// Controls the z index of this floating element and all its children. Floating elements are sorted in ascending z order before output.
	// zIndex is also passed to the renderer for all elements contained within this floating element.
	zIndex:             i16,
	attachPoints:       FloatingAttachPoints,

	// Controls how mouse pointer events like hover and click are captured or passed through to elements underneath a floating element.
	// CLAY_POINTER_CAPTURE_MODE_CAPTURE (default) - "Capture" the pointer event and don't allow events like hover and click to pass through to elements underneath.
	// CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH - Transparently pass through pointer events like hover and click to elements underneath the floating element.
	pointerCaptureMode: PointerCaptureMode,

	// Controls which element a floating element is "attached" to (i.e. relative offset from).
	// CLAY_ATTACH_TO_NONE (default) - Disables floating for this element.
	// CLAY_ATTACH_TO_PARENT - Attaches this floating element to its parent, positioned based on the .attachPoints and .offset fields.
	// CLAY_ATTACH_TO_ELEMENT_WITH_ID - Attaches this floating element to an element with a specific ID, specified with the .parentId field. positioned based on the .attachPoints and .offset fields.
	// CLAY_ATTACH_TO_ROOT - Attaches this floating element to the root of the layout, which combined with the .offset field provides functionality similar to "absolute positioning".
	attachTo:           FloatingAttachToElement,

	// Controls whether or not a floating element is clipped to the same clipping rectangle as the element it's attached to.
	// CLAY_CLIP_TO_NONE (default) - The floating element does not inherit clipping.
	// CLAY_CLIP_TO_ATTACHED_PARENT - The floating element is clipped to the same clipping rectangle as the element it's attached to.
	clipTo:             FloatingClipToElement,
}

_FloatingElementConfigWrapper :: struct {
	wrapped: FloatingElementConfig,
}

// Controls various settings related to custom elements.
CustomElementConfig :: struct {
	// A transparent pointer through which you can pass custom data to the renderer.
	// Generates CUSTOM render commands.
	customData: rawptr,
}

_CustomElementConfigWrapper :: struct {
	wrapped: CustomElementConfig,
}

// Controls the axis on which an element switches to "scrolling", which clips the contents and allows scrolling in that direction.
ClipElementConfig :: struct {
	horizontal:  i32, // Clip overflowing elements on the X axis.
	vertical:    i32, // Clip overflowing elements on the Y axis.
	childOffset: Vector2, // Offsets the x,y positions of all child elements. Used primarily for scrolling containers.
}

ClipElementConfigWrapper :: struct {
	wrapped: ClipElementConfig,
}

// Controls the widths of individual element borders.
BorderWidth :: struct {
	left:            u16,
	right:           u16,
	top:             u16,
	bottom:          u16,

	// Creates borders between each child element, depending on the .layoutDirection.
	// e.g. for LEFT_TO_RIGHT, borders will be vertical lines, and for TOP_TO_BOTTOM borders will be horizontal lines.
	// .betweenChildren borders will result in individual RECTANGLE render commands being generated.
	betweenChildren: u16,
}

// Controls settings related to element borders.
BorderElementConfig :: struct {
	color: Color, // Controls the color of all borders with width > 0. Conventionally represented as 0-255, but interpretation is up to the renderer.
	width: BorderWidth, // Controls the widths of individual borders. At least one of these should be > 0 for a BORDER render command to be generated.
}

BorderElementConfigWrapper :: struct {
	wrapped: BorderElementConfig,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_TEXT
TextRenderData :: struct {
	// A string slice containing the text to be rendered.
	// Note: this is not guaranteed to be null terminated.
	stringContents: StringSlice,

	// Conventionally represented as 0-255 for each channel, but interpretation is up to the renderer.
	textColor:      Color,

	// An integer representing the font to use to render this text, transparently passed through from the text declaration.
	fontId:         u16,
	fontSize:       u16,

	// Specifies the extra whitespace gap in pixels between each character.
	letterSpacing:  u16,

	// The height of the bounding box for this line of text.
	lineHeight:     u16,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_RECTANGLE
RectangleRenderData :: struct {
	// The solid background color to fill this rectangle with. Conventionally represented as 0-255 for each channel, but interpretation is up to the renderer.
	backgroundColor: Color,

	// Controls the "radius", or corner rounding of elements, including rectangles, borders and images.
	// The rounding is determined by drawing a circle inset into the element corner by (radius, radius) pixels.
	cornerRadius:    CornerRadius,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_IMAGE
ImageRenderData :: struct {
	// The tint color for this image. Note that the default value is 0,0,0,0 and should likely be interpreted
	// as "untinted".
	// Conventionally represented as 0-255 for each channel, but interpretation is up to the renderer.
	backgroundColor: Color,

	// Controls the "radius", or corner rounding of this image.
	// The rounding is determined by drawing a circle inset into the element corner by (radius, radius) pixels.
	cornerRadius:    CornerRadius,

	// A pointer transparently passed through from the original element definition, typically used to represent image data.
	imageData:       rawptr,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_CUSTOM
CustomRenderData :: struct {
	// Passed through from .backgroundColor in the original element declaration.
	// Conventionally represented as 0-255 for each channel, but interpretation is up to the renderer.
	backgroundColor: Color,

	// Controls the "radius", or corner rounding of this custom element.
	// The rounding is determined by drawing a circle inset into the element corner by (radius, radius) pixels.
	cornerRadius:    CornerRadius,

	// A pointer transparently passed through from the original element definition.
	customData:      rawptr,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_SCISSOR_START || commandType == CLAY_RENDER_COMMAND_TYPE_SCISSOR_END
ScrollRenderData :: struct {
	horizontal: i32,
	vertical:   i32,
}

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_SCISSOR_START || commandType == CLAY_RENDER_COMMAND_TYPE_SCISSOR_END
ClipRenderData :: ScrollRenderData

// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_BORDER
BorderRenderData :: struct {
	// Controls a shared color for all this element's borders.
	// Conventionally represented as 0-255 for each channel, but interpretation is up to the renderer.
	color:        Color,

	// Specifies the "radius", or corner rounding of this border element.
	// The rounding is determined by drawing a circle inset into the element corner by (radius, radius) pixels.
	cornerRadius: CornerRadius,

	// Controls individual border side widths.
	width:        BorderWidth,
}

// A struct union containing data specific to this command's .commandType
RenderData :: struct #raw_union {
	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_RECTANGLE
	rectangle: RectangleRenderData,

	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_TEXT
	text:      TextRenderData,

	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_IMAGE
	image:     ImageRenderData,

	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_CUSTOM
	custom:    CustomRenderData,

	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_BORDER
	border:    BorderRenderData,

	// Render command data when commandType == CLAY_RENDER_COMMAND_TYPE_SCISSOR_START|END
	clip:      ClipRenderData,
}

// Data representing the current internal state of a scrolling element.
ScrollContainerData :: struct {
	// Note: This is a pointer to the real internal scroll position, mutating it may cause a change in final layout.
	// Intended for use with external functionality that modifies scroll position, such as scroll bars or auto scrolling.
	scrollPosition:            ^Vector2,

	// The bounding box of the scroll element.
	scrollContainerDimensions: Dimensions,

	// The outer dimensions of the inner scroll container content, including the padding of the parent scroll container.
	contentDimensions:         Dimensions,

	// The config that was originally passed to the clip element.
	config:                    ClipElementConfig,

	// Indicates whether an actual scroll container matched the provided ID or if the default struct was returned.
	found:                     i32,
}

// Bounding box and other data for a specific UI element.
ElementData :: struct {
	// The rectangle that encloses this UI element, with the position relative to the root of the layout.
	boundingBox: BoundingBox,

	// Indicates whether an actual Element matched the provided ID or if the default struct was returned.
	found:       i32,
}

// Used by renderers to determine specific handling for each render command.
RenderCommandType :: enum u8 {
	// Used by renderers to determine specific handling for each render command.
	// packed                                 = -1,

	// This command type should be skipped.
	RENDER_COMMAND_TYPE_NONE          = 0,

	// The renderer should draw a solid color rectangle.
	RENDER_COMMAND_TYPE_RECTANGLE     = 1,

	// The renderer should draw a colored border inset into the bounding box.
	RENDER_COMMAND_TYPE_BORDER        = 2,

	// The renderer should draw text.
	RENDER_COMMAND_TYPE_TEXT          = 3,

	// The renderer should draw an image.
	RENDER_COMMAND_TYPE_IMAGE         = 4,

	// The renderer should begin clipping all future draw commands, only rendering content that falls within the provided boundingBox.
	RENDER_COMMAND_TYPE_SCISSOR_START = 5,

	// The renderer should finish any previously active clipping, and begin rendering elements in full again.
	RENDER_COMMAND_TYPE_SCISSOR_END   = 6,

	// The renderer should provide a custom implementation for handling this render command based on its .customData
	RENDER_COMMAND_TYPE_CUSTOM        = 7,
}

RenderCommand :: struct {
	// A rectangular box that fully encloses this UI element, with the position relative to the root of the layout.
	boundingBox: BoundingBox,

	// A struct union containing data specific to this command's commandType.
	renderData:  RenderData,

	// A pointer transparently passed through from the original element declaration.
	userData:    rawptr,

	// The id of this element, transparently passed through from the original element declaration.
	id:          u32,

	// The z order required for drawing this command correctly.
	// Note: the render command array is already sorted in ascending order, and will produce correct results if drawn in naive order.
	// This field is intended for use in batching renderers for improved performance.
	zIndex:      i16,

	// Specifies how to handle rendering of this command.
	// CLAY_RENDER_COMMAND_TYPE_RECTANGLE - The renderer should draw a solid color rectangle.
	// CLAY_RENDER_COMMAND_TYPE_BORDER - The renderer should draw a colored border inset into the bounding box.
	// CLAY_RENDER_COMMAND_TYPE_TEXT - The renderer should draw text.
	// CLAY_RENDER_COMMAND_TYPE_IMAGE - The renderer should draw an image.
	// CLAY_RENDER_COMMAND_TYPE_SCISSOR_START - The renderer should begin clipping all future draw commands, only rendering content that falls within the provided boundingBox.
	// CLAY_RENDER_COMMAND_TYPE_SCISSOR_END - The renderer should finish any previously active clipping, and begin rendering elements in full again.
	// CLAY_RENDER_COMMAND_TYPE_CUSTOM - The renderer should provide a custom implementation for handling this render command based on its .customData
	commandType: RenderCommandType,
}

// A sized array of render commands.
RenderCommandArray :: struct {
	// The underlying max capacity of the array, not necessarily all initialized.
	capacity:      i32,

	// The number of initialized elements in this array. Used for loops and iteration.
	length:        i32,

	// A pointer to the first element in the internal array.
	internalArray: ^RenderCommand,
}

// Represents the current state of interaction with clay this frame.
PointerDataInteractionState :: enum u8 {
	// Represents the current state of interaction with clay this frame.
	// packed                                = -1,

	// A left mouse click, or touch occurred this frame.
	POINTER_DATA_PRESSED_THIS_FRAME  = 0,

	// The left mouse button click or touch happened at some point in the past, and is still currently held down this frame.
	POINTER_DATA_PRESSED             = 1,

	// The left mouse button click or touch was released this frame.
	POINTER_DATA_RELEASED_THIS_FRAME = 2,

	// The left mouse button click or touch is not currently down / was released at some point in the past.
	POINTER_DATA_RELEASED            = 3,
}

// Information on the current state of pointer interactions this frame.
PointerData :: struct {
	// The position of the mouse / touch / pointer relative to the root of the layout.
	position: Vector2,

	// Represents the current state of interaction with clay this frame.
	// CLAY_POINTER_DATA_PRESSED_THIS_FRAME - A left mouse click, or touch occurred this frame.
	// CLAY_POINTER_DATA_PRESSED - The left mouse button click or touch happened at some point in the past, and is still currently held down this frame.
	// CLAY_POINTER_DATA_RELEASED_THIS_FRAME - The left mouse button click or touch was released this frame.
	// CLAY_POINTER_DATA_RELEASED - The left mouse button click or touch is not currently down / was released at some point in the past.
	state:    PointerDataInteractionState,
}

ElementDeclaration :: struct {
	// Controls various settings that affect the size and position of an element, as well as the sizes and positions of any child elements.
	layout:          LayoutConfig,

	// Controls the background color of the resulting element.
	// By convention specified as 0-255, but interpretation is up to the renderer.
	// If no other config is specified, .backgroundColor will generate a RECTANGLE render command, otherwise it will be passed as a property to IMAGE or CUSTOM render commands.
	backgroundColor: Color,

	// Controls the "radius", or corner rounding of elements, including rectangles, borders and images.
	cornerRadius:    CornerRadius,

	// Controls settings related to aspect ratio scaling.
	aspectRatio:     AspectRatioElementConfig,

	// Controls settings related to image elements.
	image:           ImageElementConfig,

	// Controls whether and how an element "floats", which means it layers over the top of other elements in z order, and doesn't affect the position and size of siblings or parent elements.
	// Note: in order to activate floating, .floating.attachTo must be set to something other than the default value.
	floating:        FloatingElementConfig,

	// Used to create CUSTOM render commands, usually to render element types not supported by Clay.
	custom:          CustomElementConfig,

	// Controls whether an element should clip its contents, as well as providing child x,y offset configuration for scrolling.
	clip:            ClipElementConfig,

	// Controls settings related to element borders, and will generate BORDER render commands.
	border:          BorderElementConfig,

	// A pointer that will be transparently passed through to resulting render commands.
	userData:        rawptr,
}

ElementDeclarationWrapper :: struct {
	wrapped: ElementDeclaration,
}

// Represents the type of error clay encountered while computing layout.
ErrorType :: enum u8 {
	// Represents the type of error clay encountered while computing layout.
	// packed                                                 = -1,

	// A text measurement function wasn't provided using SetMeasureTextFunction(), or the provided function was null.
	ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED = 0,

	// Clay attempted to allocate its internal data structures but ran out of space.
	// The arena passed to Initialize was created with a capacity smaller than that required by MinMemorySize().
	ERROR_TYPE_ARENA_CAPACITY_EXCEEDED                = 1,

	// Clay ran out of capacity in its internal array for storing elements. This limit can be increased with SetMaxElementCount().
	ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED             = 2,

	// Clay ran out of capacity in its internal array for storing elements. This limit can be increased with SetMaxMeasureTextCacheWordCount().
	ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED     = 3,

	// Two elements were declared with exactly the same ID within one layout.
	ERROR_TYPE_DUPLICATE_ID                           = 4,

	// A floating element was declared using ATTACH_TO_ELEMENT_ID and either an invalid .parentId was provided or no element with the provided .parentId was found.
	ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND    = 5,

	// An element was declared that using SIZING_PERCENT but the percentage value was over 1. Percentage values are expected to be in the 0-1 range.
	ERROR_TYPE_PERCENTAGE_OVER_1                      = 6,

	// Clay encountered an internal error. It would be wonderful if you could report this so we can fix it!
	ERROR_TYPE_INTERNAL_ERROR                         = 7,

	// _OpenElement was called more times than _CloseElement, so there were still remaining open elements when the layout ended.
	ERROR_TYPE_UNBALANCED_OPEN_CLOSE                  = 8,
}

// Data to identify the error that clay has encountered.
ErrorData :: struct {
	// Represents the type of error clay encountered while computing layout.
	// CLAY_ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED - A text measurement function wasn't provided using SetMeasureTextFunction(), or the provided function was null.
	// CLAY_ERROR_TYPE_ARENA_CAPACITY_EXCEEDED - Clay attempted to allocate its internal data structures but ran out of space. The arena passed to Initialize was created with a capacity smaller than that required by MinMemorySize().
	// CLAY_ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED - Clay ran out of capacity in its internal array for storing elements. This limit can be increased with SetMaxElementCount().
	// CLAY_ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED - Clay ran out of capacity in its internal array for storing elements. This limit can be increased with SetMaxMeasureTextCacheWordCount().
	// CLAY_ERROR_TYPE_DUPLICATE_ID - Two elements were declared with exactly the same ID within one layout.
	// CLAY_ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND - A floating element was declared using CLAY_ATTACH_TO_ELEMENT_ID and either an invalid .parentId was provided or no element with the provided .parentId was found.
	// CLAY_ERROR_TYPE_PERCENTAGE_OVER_1 - An element was declared that using CLAY_SIZING_PERCENT but the percentage value was over 1. Percentage values are expected to be in the 0-1 range.
	// CLAY_ERROR_TYPE_INTERNAL_ERROR - Clay encountered an internal error. It would be wonderful if you could report this so we can fix it!
	errorType: ErrorType,

	// A string containing human-readable error text that explains the error in more detail.
	errorText: String,

	// A transparent pointer passed through from when the error handler was first provided.
	userData:  rawptr,
}

// A wrapper struct around Clay's error handler function.
ErrorHandler :: struct {
	// A user provided function to call when Clay encounters an error during layout.
	errorHandlerFunction: proc "c" (errorText: ErrorData),

	// A pointer that will be transparently passed through to the error handler when it is called.
	userData:             rawptr,
}

@(link_prefix = "Clay_", default_calling_convention = "c")
foreign Clay {
	// Returns the size, in bytes, of the minimum amount of memory Clay requires to operate at its current settings.
	MinMemorySize :: proc() -> u32 ---

	// Creates an arena for clay to use for its internal allocations, given a certain capacity in bytes and a pointer to an allocation of at least that size.
	// Intended to be used with MinMemorySize in the following way:
	// uint32_t minMemoryRequired = MinMemorySize();
	// Arena clayMemory = CreateArenaWithCapacityAndMemory(minMemoryRequired, malloc(minMemoryRequired));
	CreateArenaWithCapacityAndMemory :: proc(capacity: i32, memory: rawptr) -> Arena ---

	// Sets the state of the "pointer" (i.e. the mouse or touch) in Clay's internal data. Used for detecting and responding to mouse events in the debug view,
	// as well as for Hovered() and scroll element handling.
	SetPointerState :: proc(position: Vector2, pointerDown: bool) ---

	// Initialize Clay's internal arena and setup required data before layout can begin. Only needs to be called once.
	// - arena can be created using CreateArenaWithCapacityAndMemory()
	// - layoutDimensions are the initial bounding dimensions of the layout (i.e. the screen width and height for a full screen layout)
	// - errorHandler is used by Clay to inform you if something has gone wrong in configuration or layout.
	Initialize :: proc(arena: Arena, layoutDimensions: Dimensions, errorHandler: ErrorHandler) -> ^Context ---

	// Returns the Context that clay is currently using. Used when using multiple instances of clay simultaneously.
	GetCurrentContext :: proc() -> ^Context ---

	// Sets the context that clay will use to compute the layout.
	// Used to restore a context saved from GetCurrentContext when using multiple instances of clay simultaneously.
	SetCurrentContext :: proc(_context: ^Context) ---

	// Updates the state of Clay's internal scroll data, updating scroll content positions if scrollDelta is non zero, and progressing momentum scrolling.
	// - enableDragScrolling when set to true will enable mobile device like "touch drag" scroll of scroll containers, including momentum scrolling after the touch has ended.
	// - scrollDelta is the amount to scroll this frame on each axis in pixels.
	// - deltaTime is the time in seconds since the last "frame" (scroll update)
	UpdateScrollContainers :: proc(enableDragScrolling: bool, scrollDelta: Vector2, deltaTime: f32) ---

	// Returns the internally stored scroll offset for the currently open element.
	// Generally intended for use with clip elements to create scrolling containers.
	GetScrollOffset :: proc() -> Vector2 ---

	// Updates the layout dimensions in response to the window or outer container being resized.
	SetLayoutDimensions :: proc(dimensions: Dimensions) ---

	// Called before starting any layout declarations.
	BeginLayout :: proc() ---

	// Called when all layout declarations are finished.
	// Computes the layout and generates and returns the array of render commands to draw.
	EndLayout :: proc() -> RenderCommandArray ---

	// Calculates a hash ID from the given idString.
	// Generally only used for dynamic strings when CLAY_ID("stringLiteral") can't be used.
	GetElementId :: proc(idString: String) -> ElementId ---

	// Calculates a hash ID from the given idString and index.
	// - index is used to avoid constructing dynamic ID strings in loops.
	// Generally only used for dynamic strings when CLAY_IDI("stringLiteral", index) can't be used.
	GetElementIdWithIndex :: proc(idString: String, index: u32) -> ElementId ---

	// Returns layout data such as the final calculated bounding box for an element with a given ID.
	// The returned ElementData contains a `found` bool that will be true if an element with the provided ID was found.
	// This ID can be calculated either with CLAY_ID() for string literal IDs, or GetElementId for dynamic strings.
	GetElementData :: proc(id: ElementId) -> ElementData ---

	// Returns true if the pointer position provided by SetPointerState is within the current element's bounding box.
	// Works during element declaration, e.g. CLAY({ .backgroundColor = Hovered() ? BLUE : RED });
	Hovered :: proc() -> i32 ---

	// Bind a callback that will be called when the pointer position provided by SetPointerState is within the current element's bounding box.
	// - onHoverFunction is a function pointer to a user defined function.
	// - userData is a pointer that will be transparently passed through when the onHoverFunction is called.
	OnHover :: proc(onHoverFunction: proc "c" (elementId: ElementId, pointerData: PointerData, userData: c.intptr_t), userData: c.intptr_t) ---

	// An imperative function that returns true if the pointer position provided by SetPointerState is within the element with the provided ID's bounding box.
	// This ID can be calculated either with CLAY_ID() for string literal IDs, or GetElementId for dynamic strings.
	PointerOver :: proc(elementId: ElementId) -> i32 ---

	// Returns the array of element IDs that the pointer is currently over.
	GetPointerOverIds :: proc() -> ElementIdArray ---

	// Returns data representing the state of the scrolling element with the provided ID.
	// The returned ScrollContainerData contains a `found` bool that will be true if a scroll element was found with the provided ID.
	// An imperative function that returns true if the pointer position provided by SetPointerState is within the element with the provided ID's bounding box.
	// This ID can be calculated either with CLAY_ID() for string literal IDs, or GetElementId for dynamic strings.
	GetScrollContainerData :: proc(id: ElementId) -> ScrollContainerData ---

	// Binds a callback function that Clay will call to determine the dimensions of a given string slice.
	// - measureTextFunction is a user provided function that adheres to the interface Dimensions (StringSlice text, TextElementConfig *config, void *userData);
	// - userData is a pointer that will be transparently passed through when the measureTextFunction is called.
	SetMeasureTextFunction :: proc(measureTextFunction: proc "c" (text: StringSlice, config: ^TextElementConfig, userData: rawptr) -> Dimensions, userData: rawptr) ---

	// Experimental - Used in cases where Clay needs to integrate with a system that manages its own scrolling containers externally.
	// Please reach out if you plan to use this function, as it may be subject to change.
	SetQueryScrollOffsetFunction :: proc(queryScrollOffsetFunction: proc "c" (elementId: u32, userData: rawptr) -> Vector2, userData: rawptr) ---

	// A bounds-checked "get" function for the RenderCommandArray returned from EndLayout().
	RenderCommandArray_Get :: proc(array: ^RenderCommandArray, index: i32) -> ^RenderCommand ---

	// Enables and disables Clay's internal debug tools.
	// This state is retained and does not need to be set each frame.
	SetDebugModeEnabled :: proc(enabled: i32) ---

	// Returns true if Clay's internal debug tools are currently enabled.
	IsDebugModeEnabled :: proc() -> i32 ---

	// Enables and disables visibility culling. By default, Clay will not generate render commands for elements whose bounding box is entirely outside the screen.
	SetCullingEnabled :: proc(enabled: i32) ---

	// Returns the maximum number of UI elements supported by Clay's current configuration.
	GetMaxElementCount :: proc() -> i32 ---

	// Modifies the maximum number of UI elements supported by Clay's current configuration.
	// This may require reallocating additional memory, and re-calling Initialize();
	SetMaxElementCount :: proc(maxElementCount: i32) ---

	// Returns the maximum number of measured "words" (whitespace seperated runs of characters) that Clay can store in its internal text measurement cache.
	GetMaxMeasureTextCacheWordCount :: proc() -> i32 ---

	// Modifies the maximum number of measured "words" (whitespace seperated runs of characters) that Clay can store in its internal text measurement cache.
	// This may require reallocating additional memory, and re-calling Initialize();
	SetMaxMeasureTextCacheWordCount :: proc(maxMeasureTextCacheWordCount: i32) ---

	// Resets Clay's internal text measurement cache. Useful if font mappings have changed or fonts have been reloaded.
	ResetMeasureTextCache :: proc() ---

	// Internal API functions required by macros ----------------------
	_OpenElement :: proc() ---
	_OpenElementWithId :: proc(elementId: ElementId) ---
	_ConfigureOpenElement :: proc(config: ElementDeclaration) ---
	_ConfigureOpenElementPtr :: proc(config: ^ElementDeclaration) ---
	_CloseElement :: proc() ---
	_HashString :: proc(key: String, seed: u32) -> ElementId ---
	_HashStringWithOffset :: proc(key: String, offset: u32, seed: u32) -> ElementId ---
	_OpenTextElement :: proc(text: String, textConfig: ^TextElementConfig) ---
	_StoreTextElementConfig :: proc(config: TextElementConfig) -> ^TextElementConfig ---
	_GetParentElementId :: proc() -> u32 ---
}

ConfigureOpenElement :: proc(config: ElementDeclaration) -> bool {
	_ConfigureOpenElement(config)
	return true
}

@(deferred_none = _CloseElement)
UI_WithId :: proc(id: ElementId) -> proc(config: ElementDeclaration) -> bool {
	_OpenElementWithId(id)
	return ConfigureOpenElement
}

@(deferred_none = _CloseElement)
UI_AutoId :: proc() -> proc(config: ElementDeclaration) -> bool {
	_OpenElement()
	return ConfigureOpenElement
}

UI :: proc {
	UI_WithId,
	UI_AutoId,
}

Text :: proc($text: string, config: ^TextElementConfig, allocator := context.temp_allocator) {
	wrapped := MakeString(text, allocator)
	wrapped.isStaticallyAllocated = true
	_OpenTextElement(wrapped, config)
}

TextDynamic :: proc(
	text: string,
	config: ^TextElementConfig,
	allocator := context.temp_allocator,
) {
	_OpenTextElement(MakeString(text, allocator), config)
}

TextConfig :: proc(config: TextElementConfig) -> ^TextElementConfig {
	return _StoreTextElementConfig(config)
}

PaddingAll :: proc(allPadding: u16) -> Padding {
	return {left = allPadding, right = allPadding, top = allPadding, bottom = allPadding}
}

BorderOutside :: proc(width: u16) -> BorderWidth {
	return {width, width, width, width, 0}
}

BorderAll :: proc(width: u16) -> BorderWidth {
	return {width, width, width, width, width}
}

CornerRadiusAll :: proc(radius: f32) -> CornerRadius {
	return CornerRadius{radius, radius, radius, radius}
}

SizingFit :: proc(sizeMinMax: SizingMinMax = {}) -> SizingAxis {
	return SizingAxis{type = SizingType.SIZING_TYPE_FIT, size = {minMax = sizeMinMax}}
}

SizingGrow :: proc(sizeMinMax: SizingMinMax = {}) -> SizingAxis {
	return SizingAxis{type = SizingType.SIZING_TYPE_GROW, size = {minMax = sizeMinMax}}
}

SizingFixed :: proc(size: f32) -> SizingAxis {
	return SizingAxis{type = SizingType.SIZING_TYPE_FIXED, size = {minMax = {size, size}}}
}

SizingPercent :: proc(sizePercent: f32) -> SizingAxis {
	return SizingAxis{type = SizingType.SIZING_TYPE_PERCENT, size = {percent = sizePercent}}
}

MakeString :: proc(label: string, allocator := context.temp_allocator) -> String {
	return String{chars = strings.clone_to_cstring(label, allocator), length = i32(len(label))}
}

ID :: proc(label: string, index: u32 = 0, allocator := context.temp_allocator) -> ElementId {
	return _HashString(MakeString(label, allocator), index)
}

ID_LOCAL :: proc(label: string, index: u32 = 0, allocator := context.temp_allocator) -> ElementId {
	return _HashStringWithOffset(MakeString(label, allocator), index, _GetParentElementId())
}
