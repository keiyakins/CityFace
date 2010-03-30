unit GLImages;

interface

uses
	SysUtils, DUtils;

type
	TGLImage = class
	protected
		W, H: Integer;
		Buf: array of TRGBAColor;
	public
		bAntialias: Boolean;

		constructor Create; virtual;

		property Width: Integer read W;
		property Height: Integer read H;
		procedure Resize(NewWidth, NewHeight: Integer; FillColor: TRGBAColor); virtual;

		function GetPixel(X, Y: Integer): TRGBAColor; virtual;
		procedure SetPixel(X, Y: Integer; NewColor: TRGBAColor); virtual;
		property Pixel[X, Y: Integer]: TRGBAColor read GetPixel write SetPixel;
		function GetGreyPixel(X, Y: Integer): Byte; virtual;
		procedure SetGreyPixel(X, Y: Integer; NewColor: Byte); virtual;
		property GreyPixel[X, Y: Integer]: Byte read GetGreyPixel write SetGreyPixel;

		function BakeToA: LongWord; virtual;
		function BakeToL: LongWord; virtual;
		function BakeToLA: LongWord; virtual;
		function BakeToRGBA: LongWord; virtual;
	end;

	EGLImageError = class(Exception);





implementation

uses
	GL, GLU, GLD;



procedure SetAntialias(bAntialias: Boolean);
begin
	if bAntialias then begin
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	end
	else begin
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	end;
end;



constructor TGLImage.Create;
begin
	bAntialias := True;
end;

procedure TGLImage.Resize(NewWidth, NewHeight: Integer; FillColor: TRGBAColor);
var
	I: Integer;

begin
	//if NewWidth < 0 then raise EGLImageError.Create('Resize to width ' + IntToStr(NewWidth) + ' is invalid.');
	//if NewHeight < 0 then raise EGLImageError.Create('Resize to height ' + IntToStr(NewHeight) + ' is invalid.');
	SetLength(Buf, 0);
	W := NewWidth;
	H := NewHeight;
	SetLength(Buf, W * H);
	for I := 0 to High(Buf) do
		Buf[I] := FillColor
	;
end;

function TGLImage.GetPixel(X, Y: Integer): TRGBAColor;
begin
	if X < 0 then raise EGLImageError.Create('GetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y < 0 then raise EGLImageError.Create('GetPixel Y=' + IntToStr(Y) + ' is off the image.');
	if X >= W then raise EGLImageError.Create('GetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y >= H then raise EGLImageError.Create('GetPixel Y=' + IntToStr(Y) + ' is off the image.');
	Result := Buf[X + Y*Width];
end;

procedure TGLImage.SetPixel(X, Y: Integer; NewColor: TRGBAColor);
begin
	if X < 0 then raise EGLImageError.Create('SetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y < 0 then raise EGLImageError.Create('SetPixel Y=' + IntToStr(Y) + ' is off the image.');
	if X >= W then raise EGLImageError.Create('SetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y >= H then raise EGLImageError.Create('SetPixel Y=' + IntToStr(Y) + ' is off the image.');
	Buf[X + Y*Width] := NewColor;
end;

function TGLImage.GetGreyPixel(X, Y: Integer): Byte;
begin
	if X < 0 then raise EGLImageError.Create('GetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y < 0 then raise EGLImageError.Create('GetPixel Y=' + IntToStr(Y) + ' is off the image.');
	if X >= W then raise EGLImageError.Create('GetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y >= H then raise EGLImageError.Create('GetPixel Y=' + IntToStr(Y) + ' is off the image.');
	with Buf[X + Y*Width] do
		Result := (R + G + B + 1) div 3
	;
end;

procedure TGLImage.SetGreyPixel(X, Y: Integer; NewColor: Byte);
begin
	if X < 0 then raise EGLImageError.Create('SetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y < 0 then raise EGLImageError.Create('SetPixel Y=' + IntToStr(Y) + ' is off the image.');
	if X >= W then raise EGLImageError.Create('SetPixel X=' + IntToStr(X) + ' is off the image.');
	if Y >= H then raise EGLImageError.Create('SetPixel Y=' + IntToStr(Y) + ' is off the image.');
	with Buf[X + Y*Width] do begin
		R := NewColor;
		G := NewColor;
		B := NewColor;
	end;
end;

function TGLImage.BakeToA: LongWord;
var
	BufRaw: array of Word;
	I: Integer;

begin
	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		BufRaw[I] := (Buf[I].A shl 8) or $00FF
	;

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 2, W, H, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, @BufRaw[0]);
	SetLength(BufRaw, 0);
	SetAntialias(bAntialias);
end;

function TGLImage.BakeToL: LongWord;
var
	BufRaw: array of Byte;
	I: Integer;

begin
	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		with Buf[I] do
			BufRaw[I] := (R + B + G + 1) div 3
	;

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 1, W, H, GL_LUMINANCE, GL_UNSIGNED_BYTE, @BufRaw[0]);
	SetLength(BufRaw, 0);
	SetAntialias(bAntialias);
end;

function TGLImage.BakeToLA: LongWord;
var
	BufRaw: array of Word;
	I: Integer;

begin
	SetLength(BufRaw, W * H);
	for I := 0 to High(BufRaw) do
		with Buf[I] do
			BufRaw[I] := (A shl 8) or ((R + B + G + 1) div 3)
	;

	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 2, W, H, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, @BufRaw[0]);
	SetLength(BufRaw, 0);
	SetAntialias(bAntialias);
end;

function TGLImage.BakeToRGBA: LongWord;
begin
	glGenTextures(1, @Result);
	SetBoundTexture(Result);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 4, W, H, GL_RGBA, GL_UNSIGNED_BYTE, @Buf[0]);
	SetAntialias(bAntialias);
end;

end.
