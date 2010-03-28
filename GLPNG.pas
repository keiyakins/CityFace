unit GLPNG;

interface

procedure InitGLibAperture;
function LoadAPNG(FilePath: String): LongWord;
function LoadLPNG(FilePath: String): LongWord;
function LoadLAPNG(FilePath: String): LongWord;
function LoadRGBAPNG(FilePath: String): LongWord;





implementation

uses
	Classes,
	GL, GLU, GLD,
	DUtils,
	GLib2, GDK2Pixbuf, GTK2, DGUtils;

{
const
	PNG_COLOR_MASK_PALETTE = 1;
	PNG_COLOR_MASK_COLOR = 2;
	PNG_COLOR_MASK_ALPHA = 4;
	PNG_COLOR_TYPE_GRAY = 0;
	PNG_COLOR_TYPE_PALETTE = PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_PALETTE;
	PNG_COLOR_TYPE_RGB = PNG_COLOR_MASK_COLOR;
	PNG_COLOR_TYPE_RGB_ALPHA = PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_ALPHA;
	PNG_COLOR_TYPE_GRAY_ALPHA = PNG_COLOR_MASK_ALPHA;

	PNG_FILLER_BEFORE = 0;
	PNG_FILLER_AFTER = 1;
}

//procedure png_set_add_alpha(png_ptr: png_structp; filler: png_uint_32; filler_loc: Integer); cdecl; external 'libpng.so';

type
	//EPNGError = class(Exception);
	TRGBAPlane = record
		Width, Height: LongWord;
		Buf: array of TRGBAColor;
	end;



procedure InitGLibAperture;
begin
	GTK_Init(@ArgC, @ArgV);
end;

function ReadPNGThroughGDK(FilePath: String): TRGBAPlane;
var
	PBuf: PGDKPixbuf;
	pC: PRGBAColor;

begin
	with Result do begin
		PBuf := GDK_Pixbuf_New_From_File(PChar(FilePath), nil);
		FilePath := '';
		if PBuf = nil then begin
			Width := 0;
			Height := 0;
			Exit;
		end;

		PBuf := PixbufReformat(PBuf, GDK_COLORSPACE_RGB, True, 8, True);
		Width := GDK_Pixbuf_Get_Width(PBuf);
		Height := GDK_Pixbuf_Get_Height(PBuf);
		SetLength(Buf, Width * Height);
		pC := PRGBAColor(GDK_Pixbuf_Get_Pixels(PBuf));
		Move(pC^, Buf[0], Width * Height * SizeOf(pC^));
		G_Object_Unref(PBuf);
	end;
end;

{
function ReadPNGEvenThoughLibPNGIsStupid(FilePath: String): TRGBAPlane;
var
	png_ptr: PNG_StructP;
	info_ptr: PNG_InfoP;
	InFil: File;
	Width, Height, BitDepth, ColorType, RowBytes: LongWord;
	Pointers: array of PNG_ByteP;
	I: Integer;

begin
	png_ptr := png_create_read_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil);
	if png_ptr = nil then EPNGError.Create('Failed to create PNG read struct.');
	WriteLn('Created PNG read struct...');

	info_ptr := png_create_info_struct(png_ptr);
	if info_ptr = nil then begin
		png_destroy_read_struct(@png_ptr, nil, nil);
		EPNGError.Create('Failed to create PNG info struct.');
	end;
	WriteLn('Created PNG info struct...');
	try
		if setjmp(png_ptr.jmpbuf) <> 0 then EPNGError.Create('SetJmp failed. What that means is undocumented.');
		WriteLn('SetJmp succeeded...');

		Assign(InFil, FilePath);
		Reset(InFil, 1);
		WriteLn('Opened file...');
		try
			png_init_io(png_ptr, @InFil);
			WriteLn('PNG I/O initialized...');
			png_read_info(png_ptr, info_ptr);
			WriteLn('PNG info read...');

			png_get_IHDR(png_ptr, info_ptr, @Width, @Height, @BitDepth, @ColorType, nil, nil, nil);

			if ColorType = PNG_COLOR_TYPE_PALETTE then png_set_palette_to_rgb(png_ptr);
			if (ColorType and PNG_COLOR_MASK_COLOR) = 0 then png_set_gray_to_rgb(png_ptr);
			if (ColorType and PNG_COLOR_MASK_ALPHA) = 0 then png_set_add_alpha(png_ptr, $FF, PNG_FILLER_AFTER);
			png_read_update_info(png_ptr, info_ptr);

			RowBytes := png_get_rowbytes(png_ptr, info_ptr);
			if RowBytes <> Width * 4 then raise EPNGError.Create('RGBA row bytes not four times width.');

			Result.Width := Width;
			Result.Height := Height;
			SetLength(Result.Buf, Height * Width);
			SetLength(Pointers, Height);
			for I := 0 to Height - 1 do begin
				Pointers[Height - 1 - I] := @(Result.Buf[I * Integer(Width)].R);
			end;

			png_read_image(png_ptr, @Pointers[0]);

			SetLength(Pointers, 0);
		finally
			Close(InFil);
		end;
	finally
		png_destroy_read_struct(@png_ptr, @info_ptr, nil);
	end;
end;
}

function LoadAPNG(FilePath: String): LongWord;
var
	W, H: LongWord;
	BufMid: TRGBAPlane;
	BufRaw: array of Word;
	I: Integer;

begin
	BufMid := ReadPNGThroughGDK(FilePath);
	W := BufMid.Width;
	H := BufMid.Height;

	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		BufRaw[I] := (BufMid.Buf[I].A shl 8) or $00FF
	;
	SetLength(BufMid.Buf, 0);

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 2, W, H, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, @BufRaw[0]);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	SetLength(BufRaw, 0);
end;

function LoadLPNG(FilePath: String): LongWord;
var
	W, H: LongWord;
	BufMid: TRGBAPlane;
	BufRaw: array of Byte;
	I: Integer;

begin
	BufMid := ReadPNGThroughGDK(FilePath);
	W := BufMid.Width;
	H := BufMid.Height;

	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		with BufMid.Buf[I] do
			BufRaw[I] := (R + B + G + 1) div 3
	;
	SetLength(BufMid.Buf, 0);

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 1, W, H, GL_LUMINANCE, GL_UNSIGNED_BYTE, @BufRaw[0]);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
end;

function LoadLAPNG(FilePath: String): LongWord;
var
	W, H: LongWord;
	BufMid: TRGBAPlane;
	BufRaw: array of Word;
	I: Integer;

begin
	BufMid := ReadPNGThroughGDK(FilePath);
	W := BufMid.Width;
	H := BufMid.Height;

	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		with BufMid.Buf[I] do
			BufRaw[I] := (A shl 8) or ((R + B + G + 1) div 3)
	;
	SetLength(BufMid.Buf, 0);

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 2, W, H, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, @BufRaw[0]);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	SetLength(BufRaw, 0);
end;

function LoadRGBAPNG(FilePath: String): LongWord;
var
	W, H: LongWord;
	BufRaw: TRGBAPlane;

begin
	BufRaw := ReadPNGThroughGDK(FilePath);
	W := BufRaw.Width;
	H := BufRaw.Height;

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 4, W, H, GL_RGBA, GL_UNSIGNED_BYTE, @BufRaw.Buf[0]);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	SetLength(BufRaw.Buf, 0);
end;

end.