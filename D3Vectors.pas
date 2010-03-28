unit D3Vectors;

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
  T3Vector = record
    X, Y, Z: TReal;
  end;

  T3Matrix = record
    X, Y, Z: T3Vector;
  end;

const
  VX: T3Vector = (X: 1; Y: 0; Z: 0);
  VY: T3Vector = (X: 0; Y: 1; Z: 0);
  VZ: T3Vector = (X: 0; Y: 0; Z: 1);
  VZero: T3Vector = (X: 0; Y: 0; Z: 0);

procedure VADD(var A: T3Vector; const B: T3Vector);
function VSum(const A, B: T3Vector): T3Vector;
procedure VSUB(var A: T3Vector; const B: T3Vector);
function VDiff(const A, B: T3Vector): T3Vector;
procedure VMUL(var A: T3Vector; B: TReal); overload;
procedure VMUL(var A: T3Vector; const B: T3Vector); overload;
function VProd(const A: T3Vector; B: TReal): T3Vector; overload;
function VProd(const A, B: T3Vector): T3Vector; overload;
function VDotProd(const A, B: T3Vector): TReal;
function VCrossProd(const A, B: T3Vector): T3Vector;
procedure VNORMALIZE(var V: T3Vector);
function VNormal(const V: T3Vector): T3Vector;
function RandDir: T3Vector;
function VYaw(Degrees: TReal; const V: T3Vector): T3Vector;
function VPitch(Degrees: TReal; const V: T3Vector): T3Vector;
function VRoll(Degrees: TReal; const V: T3Vector): T3Vector;
function RotByMatrix(const RotMatrix: T3Matrix; const A: T3Vector): T3Vector;
function UnRotByMatrix(const RotMatrix: T3Matrix; const A: T3Vector): T3Vector;
procedure IsoMatrix(var M: T3Matrix);
function VLen(const V: T3Vector): TReal;
function VLen2(const V: T3Vector): TReal;
function Vector(X, Y, Z: TReal): T3Vector;





implementation

uses
  Math, MTRandomity, SysUtils;

procedure VADD(var A: T3Vector; const B: T3Vector);
begin
  A.X := A.X + B.X;
  A.Y := A.Y + B.Y;
  A.Z := A.Z + B.Z;
end;

function VSum(const A, B: T3Vector): T3Vector;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
  Result.Z := A.Z + B.Z;
end;

procedure VSUB(var A: T3Vector; const B: T3Vector);
begin
  A.X := A.X - B.X;
  A.Y := A.Y - B.Y;
  A.Z := A.Z - B.Z;
end;

function VDiff(const A, B: T3Vector): T3Vector;
begin
  Result.X := A.X - B.X;
  Result.Y := A.Y - B.Y;
  Result.Z := A.Z - B.Z;
end;

procedure VMUL(var A: T3Vector; B: TReal); overload;
begin
  A.X := A.X * B;
  A.Y := A.Y * B;
  A.Z := A.Z * B;
end;

procedure VMUL(var A: T3Vector; const B: T3Vector); overload;
begin
  A.X := A.X * B.X;
  A.Y := A.Y * B.Y;
  A.Z := A.Z * B.Z;
end;

function VPROD(const A: T3Vector; B: TReal): T3Vector; overload;
begin
  Result.X := A.X * B;
  Result.Y := A.Y * B;
  Result.Z := A.Z * B;
end;

function VPROD(const A, B: T3Vector): T3Vector; overload;
begin
  Result.X := A.X * B.X;
  Result.Y := A.Y * B.Y;
  Result.Z := A.Z * B.Z;
end;

function VDOTPROD(const A, B: T3Vector): TReal;
begin
  Result := A.X*B.X + A.Y*B.Y + A.Z*B.Z;
end;

function VCrossProd(const A, B: T3Vector): T3Vector;
begin
  Result.X := A.Y*B.Z - A.Z*B.Y;
  Result.Y := A.Z*B.X - A.X*B.Z;
  Result.Z := A.X*B.Y - A.Y*B.X;
end;

procedure VNormalize(var V: T3Vector);
var
  F: TReal;

begin
  with V do begin
    F := X*X + Y*Y + Z*Z;
    F := 1 / SqRt(F);
    X := X * F;
    Y := Y * F;
    Z := Z * F;
  end;
end;

function VNormal(const V: T3Vector): T3Vector;
var
  F: TReal;

begin
  with V do F := X*X + Y*Y + Z*Z;
  F := 1 / SqRt(F);
  Result.X := V.X * F;
  Result.Y := V.Y * F;
  Result.Z := V.Z * F;
end;

function RandDir: T3Vector;
var
  R2: TReal;

begin
  with Result do begin
    repeat
      X := RandBipolar;
      Y := RandBipolar;
      Z := RandBipolar;
      R2 := X*X + Y*Y + Z*Z;
    until (R2 >= 0.01) and (R2 <= 1);
    R2 := 1 / SqRt(R2);
    X := X * R2;
    Y := Y * R2;
    Z := Z * R2;
  end;
end;

function VYaw(Degrees: TReal; const V: T3Vector): T3Vector;
var
  EC, ES: Extended;

begin
  SinCos(Degrees * (2/360 * Pi), ES, EC);
  Result.X := V.X * EC + V.Z * ES;
  Result.Y := V.Y;
  Result.Z := V.Z * EC - V.X * ES;
end;

function VPitch(Degrees: TReal; const V: T3Vector): T3Vector;
var
  EC, ES: Extended;

begin
  SinCos(Degrees * (2/360 * Pi), ES, EC);
  Result.X := V.X;
  Result.Y := V.Y * EC + V.Z * ES;
  Result.Z := V.Z * EC - V.Y * ES;
end;

function VRoll(Degrees: TReal; const V: T3Vector): T3Vector;
var
  EC, ES: Extended;

begin
  SinCos(Degrees * (2/360 * Pi), ES, EC);
  Result.X := V.X * EC + V.Y * ES;
  Result.Y := V.Y * EC - V.X * ES;
  Result.Z := V.Z;
end;

function RotByMatrix(const RotMatrix: T3Matrix; const A: T3Vector): T3Vector;
begin
  with RotMatrix.X do Result.X := A.X * X + A.Y * Y + A.Z * Z;
  with RotMatrix.Y do Result.Y := A.X * X + A.Y * Y + A.Z * Z;
  with RotMatrix.Z do Result.Z := A.X * X + A.Y * Y + A.Z * Z;
end;

function UnRotByMatrix(const RotMatrix: T3Matrix; const A: T3Vector): T3Vector;
begin
  with RotMatrix do Result.X := A.X * X.X + A.Y * Y.X + A.Z * Z.X;
  with RotMatrix do Result.Y := A.X * X.Y + A.Y * Y.Y + A.Z * Z.Y;
  with RotMatrix do Result.Z := A.X * X.Z + A.Y * Y.Z + A.Z * Z.Z;
end;

procedure IsoMatrix(var M: T3Matrix);
begin
  with M do begin
    X := VNormal(VCrossProd(Z, Y));
    Y := VCrossProd(X, Z);
  end;
end;

function VLen(const V: T3Vector): TReal;
begin
  with V do Result := SqRt(X*X + Y*Y + Z*Z);
end;

function VLen2(const V: T3Vector): TReal;
begin
  with V do Result := X*X + Y*Y + Z*Z;
end;

function Vector(X, Y, Z: TReal): T3Vector;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

end.
