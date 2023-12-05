library sgnproc;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,  SignalProcs;

exports
  fftp,
  CreateBiSqrFilter,
  CreateIIRFilter,
  CreateBandPassFilter,
  FreeFilter,
//BiSqrFltrStep,
  FltrStep,
  FilterSignal;
end.

