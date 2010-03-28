unit D2Vectors;

interface

uses
  DUtils;

const
  Rad2 = 1.4142135623730950488016887242097;
  RadHalf = 0.707106781186547524400844362104849;
  HalfPi = Pi / 2;
  FullCircle = Pi * 2;
  Infinity = 1/0;

type
  T2Vector = record
    X, Y: TReal;
  end;

procedure VADD(var A, B: T2Vector); overload;
procedure VADD(var A: T2Vector; B: TReal); overload;
function VSum(const A, B: T2Vector): T2Vector; overload;
function VSum(const A, B, C: T2Vector): T2Vector; overload;
function VSum(const A: T2Vector; B: TReal): T2Vector; overload;
procedure VSUB(var A: T2Vector; const B: T2Vector);
function VDiff(const A, B: T2Vector): T2Vector;
procedure VMUL(var A: T2Vector; const B: T2Vector); overload;
procedure VMUL(var A: T2Vector; B: TReal); overload;
function VProd(const A: T2Vector; B: TReal): T2Vector; overload;
function VProd(const A, B: T2Vector): T2Vector; overload;
function VDotProd(const A, B: T2Vector): TReal;
procedure VNORMALIZE(var V: T2Vector);
function VNormal(const V: T2Vector): T2Vector;
function RandDir: T2Vector;
function RandInCircle: T2Vector;
function Clockwise(const V: T2Vector): T2Vector;
function ClockHalf(const V: T2Vector): T2Vector;
function Widdershins(const V: T2Vector): T2Vector;
function WidHalf(const V: T2Vector): T2Vector;
function ThetaFromVector(const Vector: T2Vector): TReal;
function VectorFromTheta(Theta: TReal): T2Vector;
function VLen(const V: T2Vector): TReal;
function VLen2(const V: T2Vector): TReal;
function VEqual(const A, B: T2Vector): Boolean;
function Vector(X, Y: TReal): T2Vector;
function Rotated(Theta: TReal; const V: T2Vector): T2Vector;
procedure VROTATE(Theta: TReal; var V: T2Vector);





implementation

uses
  Math, NixRandomity;

procedure VADD(var A, B: T2Vector); overload;
begin
  A.X := A.X + B.X;
  A.Y := A.Y + B.Y;
end;

procedure VADD(var A: T2Vector; B: TReal); overload;
begin
  A.X := A.X + B;
  A.Y := A.Y + B;
end;

function VSum(const A, B: T2Vector): T2Vector; overload;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
end;

function VSum(const A, B, C: T2Vector): T2Vector; overload;
begin
  Result.X := A.X + B.X + C.X;
  Result.Y := A.Y + B.Y + C.Y;
end;

function VSum(const A: T2Vector; B: TReal): T2Vector; overload;
begin
  Result.X := A.X + B;
  Result.Y := A.Y + B;
end;

procedure VSUB(var A: T2Vector; const B: T2Vector);
begin
  A.X := A.X - B.X;
  A.Y := A.Y - B.Y;
end;

function VDiff(const A, B: T2Vector): T2Vector;
begin
  Result.X := A.X - B.X;
  Result.Y := A.Y - B.Y;
end;

procedure VMUL(var A: T2Vector; const B: T2Vector); overload;
begin
  A.X := A.X * B.X;
  A.Y := A.Y * B.Y;
end;

procedure VMUL(var A: T2Vector; B: TReal); overload;
begin
  A.X := A.X * B;
  A.Y := A.Y * B;
end;

function VProd(const A: T2Vector; B: TReal): T2Vector; overload;
begin
  Result.X := A.X * B;
  Result.Y := A.Y * B;
end;

function VProd(const A, B: T2Vector): T2Vector; overload;
begin
  Result.X := A.X * B.X;
  Result.Y := A.Y * B.Y;
end;

function VDotProd(const A, B: T2Vector): TReal;
begin
  Result := A.X*B.X + A.Y*B.Y;
end;

procedure VNORMALIZE(var V: T2Vector);
var
  F: TReal;

begin
  with V do begin
    F := X*X + Y*Y;
    F := 1 / SqRt(F);
    X := X * F;
    Y := Y * F;
  end;
end;

function VNormal(const V: T2Vector): T2Vector;
var
  F: TReal;

begin
  with V do F := X*X + Y*Y;
  F := SqRt(F);
  F := 1 / F;
  Result.X := V.X * F;
  Result.Y := V.Y * F;
end;

function RandDir: T2Vector;
var
  R2: TReal;

begin
  with Result do begin
    repeat
      X := RandBipolar;
      Y := RandBipolar;
      R2 := X*X + Y*Y;
    until (R2 >= 0.01) and (R2 <= 1);
    R2 := 1 / SqRt(R2);
    X := X * R2;
    Y := Y * R2;
  end;
end;

function RandInCircle: T2Vector;
var
  R2: TReal;

begin
  with Result do begin
    repeat
      X := RandBipolar;
      Y := RandBipolar;
      R2 := X*X + Y*Y;
    until R2 <= 1;
  end;
end;

function VLen(const V: T2Vector): TReal;
begin
  with V do Result := SqRt(X*X + Y*Y);
end;

function VLen2(const V: T2Vector): TReal; 
begin
  with V do Result := X*X + Y*Y;
end;

function VEqual(const A, B: T2Vector): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

function Vector(X, Y: TReal): T2Vector;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Clockwise(const V: T2Vector): T2Vector;
begin
  Result.X := -V.Y;
  Result.Y := V.X;
end;

function Widdershins(const V: T2Vector): T2Vector;
begin
  Result.X := V.Y;
  Result.Y := -V.X;
end;

function ClockHalf(const V: T2Vector): T2Vector;
begin
  Result.X := (V.X - V.Y) * RadHalf;
  Result.Y := (V.Y + V.X) * RadHalf;
end;

function WidHalf(const V: T2Vector): T2Vector;
begin
  Result.X := (V.X + V.Y) * RadHalf;
  Result.Y := (V.Y - V.X) * RadHalf;
end;

function ThetaFromVector(const Vector: T2Vector): TReal;
begin
  if Vector.Y = 0 then begin
    if Vector.X < 0 then
      Result := -HalfPi
    else
      Result := HalfPi
    ;
  end
  else
    Result := ArcTan2(Vector.X, -Vector.Y)
  ;
end;

function VectorFromTheta(Theta: TReal): T2Vector;
var
  ES, EC: Extended;

begin
  SinCos(Theta, ES, EC);
  Result.X := ES;
  Result.Y := -EC;
end;

function Rotated(Theta: TReal; const V: T2Vector): T2Vector;
var
  ES, EC: Extended;

begin
  SinCos(Theta, ES, EC);
  Result.X := V.X * EC - V.Y * ES;
  Result.Y := V.Y * EC + V.X * ES;
end;

procedure VROTATE(Theta: TReal; var V: T2Vector);
begin
  V := Rotated(Theta, V);
end;

end.
