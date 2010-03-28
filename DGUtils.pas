unit DGUtils;

interface

uses
	GLib2,
	GDK2Pixbuf;

function GStrToStr(GStr: PChar): String;

function StrToUTF8(S: String): String;
function UTF8ToStr(U: String): String;

function PixbufReformat(Src: PGDKPixbuf; NewColorspace: TGDKColorspace; NewHasAlpha: Boolean; NewBitsPerSample: Integer; bUnrefSrc: Boolean = False): PGDKPixbuf;
function PixbufRescale(Src: PGDKPixbuf; NewWidth, NewHeight: Integer; Interp: TGDKInterpType; bUnrefSrc: Boolean = False): PGDKPixbuf;





implementation

function GStrToStr(GStr: PChar): String;
begin
	Result := GStr;
	G_Free(GStr);
end;



function StrToUTF8(S: String): String;
var
	pResult: PChar;
	Len: Integer;

begin
	pResult := G_Convert(@S[1], Length(S), 'UTF-8', 'Windows-1252', nil, @Len, nil);
	if pResult = nil then
		Result := ''
	else begin
		SetString(Result, pResult, Len);
		G_Free(pResult);
	end;
end;

function UTF8ToStr(U: String): String;
var
	pResult: PChar;
	Len: Integer;

begin
	pResult := G_Convert(@U[1], Length(U), 'Windows-1252', 'UTF-8', nil, @Len, nil);
	if pResult = nil then
		Result := ''
	else begin
		SetString(Result, pResult, Len);
		G_Free(pResult);
	end;
end;



function PixbufReformat(Src: PGDKPixbuf; NewColorspace: TGDKColorspace; NewHasAlpha: Boolean; NewBitsPerSample: Integer; bUnrefSrc: Boolean = False): PGDKPixbuf;
var
	W, H: Integer;

begin
	W := GDK_Pixbuf_Get_Width(Src);
	H := GDK_Pixbuf_Get_Height(Src);
	Result := PGDKPixbuf(GDK_Pixbuf_New(NewColorspace, NewHasAlpha, NewBitsPerSample, W, H));
	GDK_Pixbuf_Copy_Area(Src, 0, 0, W, H, Result, 0, 0);
	if bUnrefSrc then G_Object_Unref(Src);
end;

function PixbufRescale(Src: PGDKPixbuf; NewWidth, NewHeight: Integer; Interp: TGDKInterpType; bUnrefSrc: Boolean = False): PGDKPixbuf;
begin
	Result := GDK_Pixbuf_Scale_Simple(Src, NewWidth, NewHeight, Interp);
	if bUnrefSrc then G_Object_Unref(Src);
end;

end.
