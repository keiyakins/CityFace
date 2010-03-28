unit SpaceTextures;

interface

type
	TTexFont = array[Byte] of LongWord;

var
	MyFont: TTexFont;

procedure LoadTexFont(var Where: TTexFont; FontFile: String);





implementation

uses
	GL, GLU, GLD,
	DUtils, DIFFChunks;

procedure LoadTexFont(var Where: TTexFont; FontFile: String);
var
	FontChunk: TDIFFChunk;
	BufSrc: String;
	BufRaw: array of Word;
	CharI: Integer;
	X, Y, W, H: Integer;

begin
	FontChunk := TDIFFChunk.CreateFromFile(FontFile);
	W := StrAsInt(FontChunk.HeaderByName['Width']);
	H := StrAsInt(FontChunk.HeaderByName['Height']);
	SetLength(BufRaw, W * H);
	glGenTextures(256, @Where[0]);
	for CharI := 0 to 255 do begin
		BufSrc := FontChunk.HeaderByName[Char(CharI)];
		for Y := 0 to H-1 do
			for X := 0 to W-1 do
				BufRaw[Y * W + X] := (Byte(BufSrc[1 + X + Y * W]) shl 8) or $00FF
		;
		BufSrc := '';
		SetBoundTexture(Where[CharI]);
		gluBuild2DMipmaps(GL_TEXTURE_2D, 2, W, H, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, @BufRaw[0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	end;
	SetLength(BufRaw, 0);
	FontChunk.Free;
end;

end.
