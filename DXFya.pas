{Unidad con rutinas para el manejo de archivos DXF.
 También se incluyen los contenedores destinados a almacenar los diversos
 bloques usados.}
unit DXFya; {$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, LCLProc, fgl;
type
  //Tipo de entidad gráfica
  TDXFentType = (
     etyLine      //línea
    ,etyCircle    //círculo
    ,etyPolyline  //polilínea
    ,etyInsert    //bloque
  );

  TDXFentitie = class;
  TDXFentitie_list = specialize TFPGObjectList<TDXFentitie>;
  { TDXFentitie }
  {Representa a una entidad gráfica}
  TDXFentitie = class
    etype: TDXFentType;   //tipo de entidad
    id   : string;        //identificador de la entidad
    layer: string;        //capa
    color: string;        //debería ser numérico
    style: string;
    isComplex: boolean;   //indica que es una entidad compleja
    polyFlag: integer; {Bandera para polilíneas. Mapa de bits, cero por defecto:
      1 = This is a closed polyline (or a polygon mesh closed in the M direction).
      2 = Curve-fit vertices have been added.
      4 = Spline-fit vertices have been added.
      8 = This is a 3D polyline.
      16 = This is a 3D polygon mesh.
      32 = The polygon mesh is closed in the N direction.
      64 = The polyline is a polyface mesh.
      128 = The linetype pattern is generated continuously around the vertices of this polyline.}
    //propiedades gráficas
    x0, y0, z0: Double;
    x1, y1, z1: Double;
    radius: double;
    vertexs: TDXFentitie_list;   //Lista de Vertex. Solo se instancia para objetos complejos.
    blkName: string;    //usado cuando es de tipo etyInsert.
    procedure Assign(source: TDXFentitie);
    procedure WritePair(var f: text; cod0, val0: string);
    procedure MoveCoord(offX, offY: double);
    function AddVertex(x, y: double): TDXFentitie;
    procedure WriteToFile(var f: text);  //escribe entidad en archivo
    destructor Destroy; override;
  private
  end;
  TDXFfile = class;
  { TDXFblock }
  {Representa a un objeto bloque.}
  TDXFblock = class
    name   : string;      //nombre
    layer  : string;      //capa
    blkFlag: integer; {Block-type flags (bit-coded values, may be combined):
          0 = Indicates none of the following flags apply
          1 = This is an anonymous block generated by hatching, associative dimensioning,
          other internal operations, or an application
          2 = This block has non-constant attribute definitions (this bit is not set if the
          block has any attribute definitions that are constant, or has no attribute definitions at all)
          4 = This block is an external reference (xref)
          8 = This block is an xref overlay
          16 = This block is externally dependent
          32 = This is a resolved external reference, or dependent of an external reference
          (ignored on input)
          64 = This definition is a referenced external reference (ignore on input)}
    x0, y0, z0: Double;
    xref      : string;  //refferencia externa a un bloque
    entities: TDXFentitie_list;  //lista de entidades
    procedure ReadEntitiesFrom(dxfFile: TDXFfile);
    procedure WritePair(var f: text; cod0, val0: string);
    procedure WriteToFile(var f: text);
    constructor Create;
    destructor Destroy; override;
  private
  end;
  TDXFblock_list = specialize TFPGObjectList<TDXFblock>;
  { TDXFfile }
  {Modela a un archivo DXF}
  TDXFfile = class
  public
    filePath: string;     //ruta y nombre del archivo DXF
    f    : text;
    Er   : string;      //mensaje de error
    cod  : integer;     //Código
    val  : string[255]; //Valor
    xMin, xMax: double;
    yMin, yMax: double;
    procedure ReadPair;
    procedure ReadSectionStart;
    procedure ReadUntilEndSection;
    procedure MoveCoord(offX, offY: double);
    function Width: double;
    function Height: double;
    procedure ExtractEntitiesAsBlock(srcDxf: TDXFfile; blkName: string);
    procedure ReadFromFile(dxfFile: string);
    procedure WriteToFile(dxfFile: string);
  public //Funciones de escritura
    procedure WritePair(cod0, val0: string);
    function AddEntitie(entType: TDXFentType): TDXFentitie;
    function AddLine(x0,y0,x1,y1: double): TDXFentitie;
    function AddCircle(x0,y0, radius: double): TDXFentitie;
    function AddPolyline(x0, y0: integer; polyFlag: integer=1): TDXFentitie;
    function AddInsert(x0, y0: double; blkName: string): TDXFentitie;
  private
    Modified : boolean;
    procedure ProcEntities;
    procedure ReadProperties(ent: TDXFentitie);
  public  //contenedores de objetos gráficoa
    entities: TDXFentitie_list;
    blocks  : TDXFblock_list;  //lista de bloques
    dummy   : TDXFentitie;     //Objeto sin uso, se usa como temporal.
  public //constructor y destructor
    constructor Create;
    destructor Destroy; override;
  end;

  TDXFfile_list = specialize TFPGObjectList<TDXFfile>;

function BloqueDXFdeArchivo(const rutDXF: string): TDXFfile;

implementation
var
  nombreArchivos: TStringList;

function BloqueDXFdeArchivo(const rutDXF: string): TDXFfile;
{Devuelve la referencia a un objeto TDXFfile que representa el contenido
del archivo DXF indicado. La lista de objetos TDXFfile se guarda en esta unidad
(nombreArchivos).
Si ya se tienen los datos de un archivo DXF, no se carga de nuevo, sino que se
devuelve la misma referencia.
La idea es que se vayan guardando los blqoues DXF, solamente de los archivos
usados, y poder devovler rápidamente uan referencia a los datos, ya que se
hará por cada material de un presupuesto.}
var
  i: Integer;
  dxf: TDXFfile;
  nomDXF: String;
begin
  //Se utiliza "nombreArchivos" para realizar búsquedas rápidas.
  nomDXF := ExtractFileName(rutDXF);   //solo busca por nombre
  if nombreArchivos.Find(nomDXF, i) then begin  //busca solo por nombre para optimizar
    //Ya existe el archivo
    Result := TDXFfile(nombreArchivos.Objects[i]);
  end else begin
    //No existe
    dxf := TDXFfile.Create;   //Crea nuevo objeto
    dxf.ReadFromFile(rutDXF); //Lee datos, puede mostrar mensajes de error
    Result := dxf;   //devuelve referencia a los datos
    nombreArchivos.AddObject(nomDXF, dxf);  //agrega la entrada para las búsquedas
  end;
end;
{ TDXFblock }
procedure TDXFblock.ReadEntitiesFrom(dxfFile: TDXFfile);
{Agrega las entidades de un archivo TDXFfile, como parte del bloque.}
var
  ent, e : TDXFentitie;
begin
  entities.Clear;
  for e in dxfFile.entities do begin
    ent := TDXFentitie.Create; //crea entidad
    ent.Assign(e);             //copia datos
    entities.Add(ent);         //agrega
  end;
end;
procedure TDXFblock.WritePair(var f: text; cod0, val0: string);
begin
  writeln(f, cod0);
  writeln(f, val0);
end;
procedure TDXFblock.WriteToFile(var f: text);
{Escribe los datos de la entidad en un archivo de texto.}
var
  ent: TDXFentitie;
begin
  WritePair(f, '0', 'BLOCK');
  WritePair(f, '8', '0');
  WritePair(f, '2', name);
  WritePair(f, '70', IntToStr(blkFlag));
  WritePair(f, '10', FloatToStr(x0));
  WritePair(f, '20', FloatToStr(y0));
  WritePair(f, '30', '0');
  WritePair(f, '3', name);
  for ent in entities do begin
    ent.WriteToFile(f);
  end;
  WritePair(f, '0', 'ENDBLK');
  //WritePair('5', '???');
  WritePair(f, '8', '0');
end;
constructor TDXFblock.Create;
begin
  entities:= TDXFentitie_list.Create(true);
end;
destructor TDXFblock.Destroy;
begin
  entities.Destroy;
  inherited Destroy;
end;
{ TDXFentitie }
procedure TDXFentitie.Assign(source: TDXFentitie);
{Copia los datos desde otra entidad}
var
  v : TDXFentitie;
  Vcop: TDXFentitie;
begin
  etype    := source.etype;
  id       := source.id;
  layer    := source.layer;
  color    := source.color;
  style    := source.style;
  isComplex:= source.isComplex;
  polyFlag := source.polyFlag;
  x0       := source.x0;
  y0       := source.y0;
  z0       := source.z0;
  x1       := source.x1;
  y1       := source.y1;
  z1       := source.z1;
  radius   := source.radius;
  //copia los VERTEX
  if source.vertexs = nil then begin
    //no tiene VERTEX
    FreeAndNil(vertexs);
  end else begin
    //Hay VERTEX
    if vertexs = nil then vertexs := TDXFentitie_list.Create(true);
    vertexs.Clear;
    for v in source.vertexs do begin
      Vcop := TDXFentitie.Create; //crea instancia
      Vcop.Assign(v);             //copia propiedades
      vertexs.Add(Vcop);          //la agrega
    end;
  end;
end;
procedure TDXFentitie.WritePair(var f: text; cod0, val0: string);
begin
  writeln(f, cod0);
  writeln(f, val0);
end;
procedure TDXFentitie.MoveCoord(offX, offY: double);
var
  vtx: TDXFentitie;
begin
  case etype of
  etyLine : begin
      //Hay que desplazar los puntos 0 y 1
      x0 += offX;
      x1 += offX;
      y0 += offY;
      y1 += offY;
    end;
  etyCircle: begin
      //Solo basta desplazar el centro
      x0 += offX;
      y0 += offY;
    end;
  etyPolyline: begin
      //Hay que desplazar todos los vértices
      for vtx in vertexs do begin
        vtx.x0 += offX;
        vtx.y0 += offY;
      end;
    end;
  end;
end;
function TDXFentitie.AddVertex(x, y: double): TDXFentitie;
{Agrega un VERTEX a la entidad. Usada para entidades complejas, como las polilíneas.}
var
  v: TDXFentitie;
begin
  if vertexs = nil then begin
    //No existe el contenedor, hay que crearlo.
    vertexs := TDXFentitie_list.Create(true);  //crea contenedor
  end;
  //crea el VERTEX y lo agrega
  v := TDXFentitie.Create;
  v.x0:=x;
  v.y0:=y;
  vertexs.Add(v);
  Result := v;
end;
procedure TDXFentitie.WriteToFile(var f: text);
{Escribe los datos de la entidad en un archivo de texto.}
var
  v: TDXFentitie;
begin
  case etype of
  etyLine: begin
      WritePair(f, '0','LINE');
      WritePair(f, '8','0');
      WritePair(f, '10', FloatToStr(x0));
      WritePair(f, '20', FloatToStr(y0));
      WritePair(f, '30', '0');
      WritePair(f, '11', FloatToStr(x1));
      WritePair(f, '21', FloatToStr(y1));
      WritePair(f, '31', '0');
    end;
  etyCircle: begin
      WritePair(f, '0', 'CIRCLE');
      WritePair(f, '8', '0');
      WritePair(f, '10', FloatToStr(x0));
      WritePair(f, '20', FloatToStr(y0));
      WritePair(f, '30', '0');
      WritePair(f, '40', FloatToStr(radius));
    end;
  etyPolyline: begin
      WritePair(f, '0', 'POLYLINE');
      WritePair(f, '8', '0');
      WritePair(f, '66','1');  //indica que es forma compleja
      WritePair(f, '10', FloatToStr(x0));
      WritePair(f, '20', FloatToStr(y0));
      WritePair(f, '30', '0');
      WritePair(f, '70', IntToStr(polyFlag));  //estilo de polilínea
      //escribe datos de los vértices
      for v in vertexs do begin
        WritePair(f, '0','VERTEX');
        WritePair(f, '8','0');
        WritePair(f, '10', FloatToStr(v.x0));
        WritePair(f, '20', FloatToStr(v.y0));
        WritePair(f, '30', '0');
      end;
      //escribe marac de fin
      WritePair(f, '0', 'SEQEND');
      WritePair(f, '8', '0');
    end;
  etyInsert: begin
      WritePair(f, '0', 'INSERT');
      WritePair(f, '8', '0');
      WritePair(f, '2', blkName);  //indica que es forma compleja
      WritePair(f, '10', FloatToStr(x0));
      WritePair(f, '20', FloatToStr(y0));
      WritePair(f, '30', '0');
    end;
  end;
end;
destructor TDXFentitie.Destroy;
begin
  if vertexs<>nil then
    vertexs.Destroy;   //en caso de que se haya creado
  inherited Destroy;
end;
{ TDXFfile }
procedure TDXFfile.ReadPair;
{Lee un par de valores del arcivo DXF}
begin
  readln(f, cod);
  readln(f, val);
end;
procedure TDXFfile.ReadSectionStart;
begin
  ReadPair;
  if val='EOF' then exit;   //caso especial
  if (val<>'SECTION') then begin
    Er := 'Error en formato de archivo: ' + filePath;
    exit;
  end;
  //Se detectó el inicio de un sección
  //Debe seguir el nombre de la sección
  ReadPair;
  DebugLn('Sección: ' + val);
end;
procedure TDXFfile.ReadUntilEndSection;
begin
  while not(eof(f)) and (val<>'ENDSEC') do begin
    ReadPair;
  end;
  if eof(f) then begin
    Er := 'Inesperado fin de archivo.';
    exit;
  end;
end;
procedure TDXFfile.MoveCoord(offX, offY: double);
{Realiza un desplazamiento de las coordenadas de las entidades, de acuerdo a los valores
indicados.}
var
  ent: TDXFentitie;
begin
  for ent in entities do begin
    ent.MoveCoord(offX, offY);
  end;
  //Actualiza valores máximos y mínimos
  xMin += offX;
  xMax += offX;
  yMin += offY;
  yMax += offY;
end;
function TDXFfile.Width: double;
{Retorna el ancho total, incluyendo a todas las entidades gráficas cargadas.}
begin
  Result := xMax - xMin;
  if Result<=0 then Result := 10;
end;
function TDXFfile.Height: double;
{Retorna el alto total, incluyendo a todas las entidades gráficas cargadas.}
begin
  Result := yMax - yMin;
  if Result<=0 then Result := 10;
end;
procedure TDXFfile.ExtractEntitiesAsBlock(srcDxf: TDXFfile; blkName: string);
{Copia las entidades del archivo indicado, y los incluye como un bloque.}
var
  blk: TDXFblock;
begin
  //Verifica si el bloque existe
  for blk in blocks do begin
    if blk.name = blkName then
      exit;  //ya existe, no lo crea de nuevo
  end;
  //Crea el nuevo bloque
  blk := TDXFblock.Create;
  blk.name:=blkName;
  blk.ReadEntitiesFrom(srcDxf);
  blocks.Add(blk);
end;
procedure TDXFfile.ReadFromFile(dxfFile: string);
{Lee el contendio de un archivo DXF. Si se genera algún error, se actualiza el mensaje
en el campo "Er".}
begin
  filePath := dxfFile;   //guarda ruta
  try
    assign(f, filePath);
    reset(f);
  except
    Er := 'Cannot read DXF file: ' + filePath;
    //CloseFile(f);
    exit;
  end;
  //Inicia lectura
  repeat
    ReadSectionStart;
    if Er<>'' then begin
      break;
    end;
    if val = 'EOF' then break;
    //Procesa sección de acuerdo al tipo
    case val of
    'ENTITIES': begin
        ProcEntities;
//        DebugLn('xmin=' + FLoatToStr(xMin) + ' xmax=' + FLoatToStr(xMax));
//        DebugLn('ymin=' + FLoatToStr(yMin) + ' ymax=' + FLoatToStr(yMax));
      end;
    else  //otra sección
      ReadUntilEndSection;
    end;
    if Er<>'' then begin
      break;
    end;
  until false;
  if Er='' then begin
    MoveCoord(-xMin, - yMin);  //desplaza al origen de coordenadas
  end;
  CloseFile(f);
end;
procedure TDXFfile.WriteToFile(dxfFile: string);
{Escribe el contenido del archivo en disso.}
var
  ent: TDXFentitie;
  blk: TDXFblock;
begin
  Assign(f, dxfFile);  //notar que usa la misma variable "f", para lectura y escritura
  ReWrite(f); {Crea el archivo}
  //Escribe información de bloques
  if blocks.Count>0 then begin
    WritePair('0','SECTION');
    WritePair('2', 'BLOCKS');
    for blk in blocks do begin
      blk.WriteToFile(f);
    end;
    WritePair('0','ENDSEC');
  end;
  //Escribe información de entidades
  WritePair('0','SECTION');
  WritePair('2', 'ENTITIES');
  for ent in entities do begin
    ent.WriteToFile(f);
  end;
  WritePair('0','ENDSEC');
  WritePair('0','EOF'); {en el archivo  }
  CloseFile(f);
end;
procedure TDXFfile.WritePair(cod0, val0: string);
begin
  writeln(f, cod0);
  writeln(f, val0);
end;
function TDXFfile.AddEntitie(entType: TDXFentType): TDXFentitie;
{Agrega una entidad a la lista de entiddades del documento. Devuelve la referencia.}
begin
  Result := TDXFentitie.Create;
  Result.etype:=entType;
  entities.Add(Result);  //agrega una línea
  Modified := true;
end;
function TDXFfile.AddLine(x0, y0, x1, y1: double): TDXFentitie;
{Agrega una entidad de tipo línea}
begin
  Result := AddEntitie(etyLine);
  Result.x0:=x0;
  Result.y0:=y0;
  Result.x1:=x1;
  Result.y1:=y1;
end;
function TDXFfile.AddCircle(x0, y0, radius: double): TDXFentitie;
begin
  Result := AddEntitie(etyCircle);
  Result.x0:=x0;
  Result.y0:=y0;
  Result.radius:=radius;
end;
function TDXFfile.AddPolyline(x0, y0: integer; polyFlag: integer): TDXFentitie;
begin
  Result := AddEntitie(etyPolyline);
  Result.x0:=x0;
  Result.y0:=y0;
  Result.polyFlag := polyFlag;  //por defecto es polilínea cerrada
  Result.isComplex := true;  //es forma compleja
end;
function TDXFfile.AddInsert(x0, y0: double; blkName: string): TDXFentitie;
{Agrega una entidad INSERT que hace referecnia a un bloque. El bloque inidcado, debe
ya existir.}
begin
  Result := AddEntitie(etyInsert);
  Result.x0:=x0;
  Result.y0:=y0;
  Result.isComplex := false;  //es forma compleja
  Result.blkName:=blkName;    //nombre del bloque
end;
procedure TDXFfile.ReadProperties(ent: TDXFentitie);
{Lee las propiedades generales de una entidad.}
begin
  repeat
    ReadPair;
    case cod of
    5  : ent.id  := val;
    //6  : ent.style := val;
    //8  : ent.layer := val;
    10 : ent.x0:=StrToFloat(val);
    20 : ent.y0:=StrToFloat(val);
    30 : ent.z0:=StrToFloat(val);
    11 : ent.x1:=StrToFloat(val);
    21 : ent.y1:=StrToFloat(val);
    31 : ent.z1:=StrToFloat(val);
    40 : ent.radius := STrToFloat(val);
    //62 : ent.color := val;
    66 : ent.isComplex := true;  //indica que siguen entidadades que son parte de esta entidad
    70 : ent.polyFlag := StrToInt(val);
    end;
  until eof(f) or (val='ENDSEC') or (cod = 0);
end;
procedure TDXFfile.ProcEntities;
{Procesa la sección de entidades, llenardo los contenedores internos de la clase
para las entidades.
Además actualiza las propiedades xMin , xMax, yMin e yMax, de acuerdo a las coordenadas
leidas.}
var
  ent, vtx: TDXFentitie;
  procedure ValidarMinX(const x: double); inline;
  begin
    if x<xMin then xMin := x;
  end;
  procedure ValidarMaxX(const x: double); inline;
  begin
    if x>xMax then xMax := x;
  end;
  procedure ValidarMinMaxX(const x: double); inline;
  begin
    if x<xMin then xMin := x;
    if x>xMax then xMax := x;
  end;
  procedure ValidarMinMaxY(const y: double); inline;
  begin
    if y<yMin then yMin := y;
    if y>yMax then yMax := y;
  end;
begin
  xMin := MaxInt;  //valor inicial para el cálculo
  xMax := -MaxInt; //valor inicial para el cálculo
  yMin := MaxInt;  //valor inicial para el cálculo
  yMAx := -MaxInt; //valor inicial para el cálculo
  ReadPair;  //lee tipo de entidad
  repeat
    if val='LINE' then begin
      //DebugLn('  línea:');
      ent := AddEntitie(etyLine);
      ReadProperties(ent); //lee propiedades
      //actualiza mínimo y máximo
      ValidarMinMaxX(ent.x0);
      ValidarMinMaxX(ent.x1);
      ValidarMinMaxY(ent.y0);
      ValidarMinMaxY(ent.y1);
    end else if val='CIRCLE' then begin
      //DebugLn('  círculo:');
      ent := AddEntitie(etyCircle);
      ReadProperties(ent); //lee propiedades
      //actualiza mínimo y máximo
      ValidarMinX(ent.x0 - ent.radius);
      ValidarMaxX(ent.x0 + ent.radius);
      ValidarMinMaxY(ent.y0 - ent.radius);
      ValidarMinMaxY(ent.y0 + ent.radius);
    end else if val='POLYLINE' then begin
      //DebugLn('  polilínea:');
      ent := AddEntitie(etyPolyline);
      ReadProperties(ent); //lee propiedades
      //Lee información de los VERTEX
      ent.vertexs := TDXFentitie_list.Create(true);  //crea contenedor
      while not eof(f) and (val<>'SEQEND') do begin
        //Debe seguir VERTEX
        if val<>'VERTEX' then begin
          Er := 'Se esperaba defin. VERTEX.';
          exit;
        end;
        //sigue un VERTEX
        vtx := TDXFentitie.Create;   //crea el objeto
        ReadProperties(vtx); //lee propiedades
        ent.vertexs.Add(vtx);    //agrega
        //DebugLn('    vertex('+FloatToStr(vtx.x0) + ',' + FloatToStr(vtx.y0));
        //actualiza mínimo y máximo
        ValidarMinMaxX(vtx.x0);
        ValidarMinMaxY(vtx.y0);
      end;
      if eof(f) then break;
      //llegó a SEQEND
      ReadProperties(dummy);  //se descarta esta entidad
    end else begin
      DebugLn('  entidad desconocida: ' + val);
      repeat
        ReadPair;
      until eof(f) or (val='ENDSEC') or (cod = 0);
    end;
    //DebugLn('  ' +val);
  until eof(f) or (val='ENDSEC');
  if eof(f) then begin
    Er := 'Inesperado fin de archivo.';
    exit;
  end;
end;
//constructor y destructor
constructor TDXFfile.Create;
begin
  entities:= TDXFentitie_list.Create(true);
  blocks  := TDXFblock_list.Create(true);
  dummy   := TDXFentitie.Create;
end;
destructor TDXFfile.Destroy;
begin
  dummy.Destroy;
  blocks.Destroy;
  entities.Destroy;
  inherited Destroy;
end;

initialization
  nombreArchivos:= TStringList.Create;
  nombreArchivos.Sorted:=true;  //para acelerar las búsquedas
  nombreArchivos.OwnsObjects:=true;  //para liberar los objetos
finalization
  nombreArchivos.Destroy;   //libera la lista y los objetos que referencia
end.

