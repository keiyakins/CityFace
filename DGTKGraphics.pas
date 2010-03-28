unit DGTKGraphics;

interface

uses
	GLib2, GDK2, GTK2,
	DUtils;

type
	TColor = type LongWord;

	TRGBAColor = packed record
	case Boolean of
		False: (R, G, B, A: Byte);
		True: (Color: TColor);
	end;
	PRGBAColor = ^TRGBAColor;

	TGDKPoints = array of TGDKPoint;

type
	TCanvas = class
	public
		Window: PGDKWindow;
		GC: PGDKGC;

		constructor Create(FromWindow: PGDKWindow); virtual;
		destructor Destroy; override;

		procedure DrawRect(bFill: Boolean; X1, Y1, X2, Y2: Integer); virtual;
		procedure FillRect(X1, Y1, X2, Y2: Integer); virtual; overload;
		procedure FillRect(const R: TGDKRectangle); virtual; overload;
		procedure FrameRect(X1, Y1, X2, Y2: Integer); virtual; overload;
		procedure FrameRect(const R: TGDKRectangle); virtual; overload;
		procedure DrawPolygon(bFill: Boolean; const Points: array of TGDKPoint); virtual;
		procedure FillPolygon(const Points: array of TGDKPoint); virtual;
		procedure FramePolygon(const Points: array of TGDKPoint); virtual;
		procedure SetRGBForeColor(R, G, B: TReal); virtual;
		procedure SetForeColor(Color: TColor); virtual;

		property ForeColor: TColor write SetForeColor;
	end;

function WidgetStateGC(Widget: PGTKWidget): PGDKGC;





implementation

function WidgetStateGC(Widget: PGTKWidget): PGDKGC;
begin
	Result := Widget.Style.FG_GC[GTK_WIDGET_STATE(Widget)];
end;

{ TCanvas }

constructor TCanvas.Create(FromWindow: PGDKWindow);
begin
	Window := FromWindow;
	GC := GDK_GC_New(Window);
end;

destructor TCanvas.Destroy;
begin
	if GC <> nil then G_Object_Unref(GC);

	inherited;
end;

procedure TCanvas.DrawRect(bFill: Boolean; X1, Y1, X2, Y2: Integer);
begin
	GDK_Draw_Rectangle(Window, GC, Ord(bFill), X1, Y1, X2, Y2);
end;

procedure TCanvas.FillRect(X1, Y1, X2, Y2: Integer);
begin
	GDK_Draw_Rectangle(Window, GC, -1, X1, Y1, X2, Y2);
end;

procedure TCanvas.FillRect(const R: TGDKRectangle);
begin
	GDK_Draw_Rectangle(Window, GC, -1, R.X, R.Y, R.Width, R.Height);
end;

procedure TCanvas.FrameRect(X1, Y1, X2, Y2: Integer);
begin
	GDK_Draw_Rectangle(Window, GC, 0, X1, Y1, X2, Y2);
end;

procedure TCanvas.FrameRect(const R: TGDKRectangle);
begin
	GDK_Draw_Rectangle(Window, GC, 0, R.X, R.Y, R.Width, R.Height);
end;

procedure TCanvas.DrawPolygon(bFill: Boolean; const Points: array of TGDKPoint);
begin
	GDK_Draw_Polygon(Window, GC, Ord(bFill), @Points[0], Length(Points));
end;

procedure TCanvas.FillPolygon(const Points: array of TGDKPoint);
begin
	GDK_Draw_Polygon(Window, GC, -1, @Points[0], Length(Points));
end;

procedure TCanvas.FramePolygon(const Points: array of TGDKPoint);
begin
	GDK_Draw_Polygon(Window, GC, 0, @Points[0], Length(Points));
end;

procedure TCanvas.SetRGBForeColor(R, G, B: TReal);
var
	C: TGDKColor;

begin
	C.Red   := InWord(R * 65535);
	C.Green := InWord(G * 65535);
	C.Blue  := InWord(B * 65535);
	GDK_GC_Set_RGB_FG_Color(GC, @C);
end;

procedure TCanvas.SetForeColor(Color: TColor);
var
	CB: TRGBAColor absolute Color;
	C: TGDKColor;

begin
	C.Red   := CB.R * $0101;
	C.Green := CB.G * $0101;
	C.Blue  := CB.B * $0101;
	GDK_GC_Set_RGB_FG_Color(GC, @C);
end;

end.
