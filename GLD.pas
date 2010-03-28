unit GLD;

interface

uses
  SysUtils, GL, GLU;

type
  PSingle = ^Single;  

//These functions, where relevant, assume Dare's coordinate system; to wit:
//+X = Right
//+Y = Down
//+Z = Forward
//+Yaw = nose goes right
//+Pitch = nose goes down
//+Roll = left goes up, right goes down

procedure gldYaw(Angle: GLFloat);
procedure gldPitch(Angle: GLFloat);
procedure gldRoll(Angle: GLFloat);
procedure gldLookAt(EyeX, EyeY, EyeZ, TarX, TarY, TarZ, UpX, UpY, UpZ: GLDouble);

function InstantArrayPtr(X: Single; Y: Single = 0; Z: Single = 0; F: Single = 0): PSingle;

procedure SetBoundTexture(hTex: LongWord);





implementation

uses
	Classes, DUtils;

var
  hLastTex: LongWord = 0;



procedure gldYaw(Angle: GLFloat);
begin
  glRotatef(Angle, 0, 1, 0);
end;

procedure gldPitch(Angle: GLFloat);
begin
  glRotatef(Angle, -1, 0, 0);
end;

procedure gldRoll(Angle: GLFloat);
begin
  glRotatef(Angle, 0, 0, 1);
end;

procedure gldLookAt(EyeX, EyeY, EyeZ, TarX, TarY, TarZ, UpX, UpY, UpZ: GLDouble);
begin
	gluLookAt(
		EyeX, EyeY, EyeZ,
		EyeX*2-TarX, EyeY*2-TarY, EyeZ*2-TarZ,
		UpX, UpY, UpZ
	);
end;



function InstantArrayPtr(X, Y, Z, F: Single): PSingle;
{$J+}
const
  Stat: array[0..3] of Single = (0, 0, 0, 0);
{$J-}

begin
  Stat[0] := X;
  Stat[1] := Y;
  Stat[2] := Z;
  Stat[3] := F;
  Result := @Stat[0];
end;



procedure SetBoundTexture(hTex: LongWord);
begin
  if hTex <> hLastTex then begin
    glBindTexture(GL_TEXTURE_2D, hTex);
    hLastTex := hTex;
  end;
end;

end.
