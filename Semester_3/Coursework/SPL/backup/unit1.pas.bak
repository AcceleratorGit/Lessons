unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uComplex, Math {SignalProcs};

const
  MaxSgnLen = 150000000;

type

  PRealArray = ^TRealArray;
  TRealArray = array[0..MaxSgnLen-1] of real;
  PComplexArray = ^TComplexArray;
  TComplexArray = array[0..MaxSgnLen-1] of complex;

  PfftRes = ^TfftRes;
  TfftRes = record
    ResSz: int64;
    ResPtr: PComplexArray;
   end;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ClearBtn: TButton;
    Button4: TButton;
    ResBox: TListBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure ClearBtnClick(Sender: TObject);
  private

  public

  end;

  TIntFunc = Function (a1: integer): integer; cdecl;
  TfftFunc = function (var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; Depth: word): TfftRes; cdecl;

   TBiSqrMatrix = record
    A1, A2, B0, B1, B2: double;
  end;

  TFltrMatrix = array[0..63] of TBiSqrMatrix;

  TCreateBiSqrFilterFunc = function (var Coeffs: TBiSqrMatrix): pointer; cdecl;
  TFreeFilterFunc = function (Fltr: pointer): wordbool; cdecl;
  TFltrStepFunc = function (Fltr: pointer; new_x: double): double; cdecl;
  TFilterSignalFunc = function (Fltr: pointer; px, py: PRealArray; SgnLen: int64): int64; cdecl;

  TCreateIIRFilterFunc = function (var Coeffs: TFltrMatrix; aHO: word): pointer; cdecl;

  TCreateBandPassFilterFunc = function (var CoeffsLow, CoeffsHigh: TFltrMatrix; aHO: word): pointer; cdecl;

var
  Form1: TForm1;

  LibName, LibSgnName: string;
  Lib, LibSgn: TLibHandle;
  LibFunc: TIntFunc;

  fftfunc: TfftFunc;

  CreateBiSqrFilterFunc: TCreateBiSqrFilterFunc;
  CreateIIRFilterFunc: TCreateIIRFilterFunc;
  FreeFilterFunc: TFreeFilterFunc;
  FltrStepFunc: TFltrStepFunc;
  FilterSignalFunc: TFilterSignalFunc;
  CreateBandPassFilterFunc: TCreateBandPassFilterFunc;


implementation

{$R *.lfm}

{ TForm1 }

var
  x: array[0..MaxSgnLen-1] of real; //=(1,1,-1,-1,1,1,-1,-1,1,1,-1,-1,1,1,-1,-1);
  // = (1,1,1,1,1,1,1,1,1,1,1,1,0,1,0,1);// (0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1);

  PX: PComplexArray;

const
  xlen: int64 = 1 shl 22;


procedure TForm1.Button1Click(Sender: TObject);
var
  ii: integer;
  fr: TfftRes;
  dt: TDateTime;
  ST: TSystemTime;
begin

  x[0]:=1;
  for ii:=1 to xlen-1 do
    x[ii]:=x[ii-1];

  {PX:=GetMem(64*SizeOf(complex));
  fft2(TRealArray(x),xlen,1,2,PX^);
  fft2(TRealArray(x),xlen,0,2,PX^);
  //ResBox.Clear;    }
  //вавава
  dt:=Now;
  if fftfunc<>nil then
    begin
      fr:=fftfunc(TRealArray(x),xlen,0,1,0);
      PX:=fr.ResPtr;
      dt:=Now-dt;
      DateTimetoSystemTime(dt,ST);
      ShowMessage(IntToStr(ST.minute)+' min. '+ IntToStr(ST.second)+' sec. '+IntToStr(ST.Millisecond)+' msec. ');
      for ii:=0 to min(63,xlen) do
      ResBox.Items.Add(CStr(PX^[ii]));
    end;

  //FreeMem(PX,64*SizeOf(complex));
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  ii: integer;
  fr: TfftRes;
  dt: TDateTime;
  ST: TSystemTime;
begin
  dt:=Now;
  fr:=fftfunc(TRealArray(x),xlen,0,1,2);
  PX:=fr.ResPtr;
  dt:=Now-dt;
  DateTimetoSystemTime(dt,ST);
  ShowMessage(IntToStr(ST.minute)+' min. '+IntToStr(ST.second)+' sec. '+IntToStr(ST.Millisecond)+' msec. ');
  for ii:=0 to min(63,xlen) do
    ResBox.Items.Add(CStr(PX^[ii]));

  // RC.DisposeLast;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  ii: integer;
  fr: TfftRes;
  dt: TDateTime;
  ST: TSystemTime;
begin
  dt:=Now;
  fr:=fftfunc(TRealArray(x),xlen,0,1,3);
  PX:=fr.ResPtr;
  dt:=Now-dt;
  DateTimetoSystemTime(dt,ST);
  ShowMessage(IntToStr(ST.minute)+' min. '+IntToStr(ST.second)+' sec. '+IntToStr(ST.Millisecond)+' msec. ');
  for ii:=0 to min(63,xlen) do
    ResBox.Items.Add(CStr(PX^[ii]));
end;


const
  x_in: array[0..19] of double = (1,2,3,4,5,6,7,7,7,7,7,6,5,4,3,2,1,1,1,1);
  x_out: array[0..22] of double = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);


{  0.06746	1
0.13491	-1.14298
0.06746	0.4128

0.07795634	 1	        0.0618852	1
0.15591268	-1.32091343	0.12377039	-1.04859958
0.07795634	0.63273879	0.0618852	0.29614036

}

procedure TForm1.Button4Click(Sender: TObject);
var
  fltr: pointer;
  CL, CH: TFltrMatrix;
  ii: integer;
  y: double;
begin
  with CL[0] do
  begin
    A1:=0.45311952;
    A2:=0.46632557;
    B0:=0.47986127;
    B1:=0.95972255;
    B2:=0.47986127;
  end;

  with CL[1]do
  begin
    A1:=0.32897568;
    A2:=0.06458765;
    B0:=0.34839083;
    B1:=0.69678167;
    B2:=0.34839083;
  end;

  with CH[0] do
  begin
    A1:=-1.58930459;
    A2:=0.75389464;
    B0:=0.70403959;
    B1:=-0.71745218;
    B2:=0.18278007;
  end;

  with CH[1]do
  begin
    A1:=-1.7835556;
    A2:=0.80804565;
    B0:=0.54912846;
    B1:=-0.55958985;
    B2:=0.14256264;
   end;

  ResBox.Clear;
  fltr:=CreateBandPassFilterFunc(CL,CH,2);

  ii:=FilterSignalFunc(fltr,@x_in,@x_out,20);
  //ShowMessage(CStr(ii));

  for ii:=0 to 19 do
  begin
    ResBox.Items.Add(CStr(x_out[ii]));
  end;

{  for ii:=0 to 19 do
  begin
    x_out[ii]:=FltrStepFunc(fltr,x_in[ii]);
    ResBox.Items.Add(CStr(x_out[ii]));
  end;   }

  FreeFilterFunc(fltr);

end;

procedure TForm1.ClearBtnClick(Sender: TObject);
begin
  ResBox.Clear;
end;

initialization

{  LibName:=GetCurrentDir+'/libtestlib.so';
  Lib:=LoadLibrary(LibName);
  LibFunc:=TIntFunc(GetProcedureAddress(Lib,'TestFunc'));  }

{$IFDEF UNIX}
  LibSgnName:=GetCurrentDir+'/libsgnproc.so';
{$ELSE}
  LibSgnName:=GetCurrentDir+'\sgnproc.dll';
{$ENDIF}

  LibSgn:=LoadLibrary(LibSgnName);
  if LibSgn<>0 then  fftfunc:=TfftFunc(GetProcedureAddress(LibSgn,'fftp'))
               else fftfunc:=nil;

  CreateBiSqrFilterFunc:=TCreateBiSqrFilterFunc(GetProcedureAddress(LibSgn,'CreateBiSqrFilter'));
  CreateIIRFilterFunc:=TCreateIIRFilterFunc(GetProcedureAddress(LibSgn,'CreateIIRFilter'));
  CreateBandPassFilterFunc:=TCreateBandPassFilterFunc(GetProcedureAddress(LibSgn,'CreateBandPassFilter'));


  FreeFilterFunc:=TFreeFilterFunc(GetProcedureAddress(LibSgn,'FreeFilter'));
  FltrStepFunc:=TFltrStepFunc(GetProcedureAddress(LibSgn,'FltrStep'));
  FilterSignalFunc:=TFilterSignalFunc(GetProcedureAddress(LibSgn,'FilterSignal'));

finalization
  if LibSgn <> 0 then FreeLibrary(LibSgn);

end.

