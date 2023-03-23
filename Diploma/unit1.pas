unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uComplex, Math,
  SignalProcs;

type

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

var
  Form1: TForm1;

  LibName: string;
  Lib: TLibHandle;
  LibFunc: TIntFunc;

implementation

{$R *.lfm}

{ TForm1 }

var
  x: array[0..150000000] of real; //=(1,1,-1,-1,1,1,-1,-1,1,1,-1,-1,1,1,-1,-1);
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
  dt:=Now;
  fr:=fft(TRealArray(x),xlen,0,1);
  PX:=fr.ResPtr;
  dt:=Now-dt;
  DateTimetoSystemTime(dt,ST);
  ShowMessage(IntToStr(ST.minute)+' min. '+ IntToStr(ST.second)+' sec. '+IntToStr(ST.Millisecond)+' msec. ');
  for ii:=0 to min(63,xlen) do
    ResBox.Items.Add(CStr(PX^[ii]));


  //RC.DisposeLast;

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
  fr:=fftp(TRealArray(x),xlen,0,1,2);
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
  fr:=fftp(TRealArray(x),xlen,0,1,3);
  PX:=fr.ResPtr;
  dt:=Now-dt;
  DateTimetoSystemTime(dt,ST);
  ShowMessage(IntToStr(ST.minute)+' min. '+IntToStr(ST.second)+' sec. '+IntToStr(ST.Millisecond)+' msec. ');
  for ii:=0 to min(63,xlen) do
    ResBox.Items.Add(CStr(PX^[ii]));
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  res: integer;
begin
  res:=LibFunc(5);
  ShowMessage(CStr(res));
end;

procedure TForm1.ClearBtnClick(Sender: TObject);
begin
  ResBox.Clear;
end;

initialization

  LibName:=GetCurrentDir+'/libtestlib.so';
  Lib:=LoadLibrary(LibName);
  LibFunc:=TIntFunc(GetProcedureAddress(Lib,'TestFunc'));



finalization
  if Lib <> 0 then FreeLibrary(Lib);

end.

