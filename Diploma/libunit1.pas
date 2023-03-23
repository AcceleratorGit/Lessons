unit libunit1;

{$mode ObjFPC}

interface


uses
  Classes, SysUtils, Dialogs, Forms;


function TestFunc(a: integer): integer; cdecl;



implementation

function TestFunc(a: integer): integer; cdecl;
begin
  try
     // ShowMessage('OK '+IntToStr(a));
     Result:=0;
  except
     Result:=-1;
  end;
end;

initialization

finalization

end.

