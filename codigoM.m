let
    // 1) Carrega e tipa a Base Rep Full (rodadas 1–7)
    FonteFull = Excel.Workbook(File.Contents("C:\\Users\\gabriel.thiago\\Downloads\\R.A 2.0_Checklist full (1).xlsx"), null, true),
    OrigemFull = FonteFull{[Item="Base Rep. full",Kind="Sheet"]}[Data],
    CabecFull = Table.PromoteHeaders(OrigemFull, [PromoteAllScalars=true]),
    CabecFullPad = Table.RenameColumns(
        CabecFull,
        {
            {"Clas. Loja", "Pot venda"},
            {"Clas. loja", "Pot venda"},
            {"Pot Venda",  "Pot venda"},
            {"Pot venda ", "Pot venda"}
        },
        MissingField.Ignore
    ),
    TipoFull = Table.TransformColumnTypes(
        CabecFullPad,
        {
            {"CANAL", type text}, {"FILIAL", Int64.Type}, {"FILIAL_NOME", type text},
            {"REGIAO", type text}, {"SKU", type text}, {"ARTIGO_COR", type text},
            {"PRODUTO", type text}, {"DESC_PRODUTO", type text}, {"COR", type text},
            {"TAM", type text}, {"TAM_GRADE", type text}, {"NEGOCIO", type text},
            {"PIRAMIDE", type text}, {"GENERO", type text}, {"IDADE_PRODUTO", type text},
            {"GRUPO_PRODUTO", type text}, {"LINHA", type text}, {"COLECAO", Int64.Type},
            {"VELOCIDADE_VENDA", type number}, {"LEADTIME", type number}, {"COBERTURA", Int64.Type},
            {"MINIMO", Int64.Type}, {"LOJA", Int64.Type}, {"TRANSITO", Int64.Type},
            {"RESERVADO", Int64.Type}, {"RESSUPRIR", Int64.Type}, {"DATA", type date},
            {"Estoque ngativo", type logical}
        }
    ),

    // 2) Função genérica para Excel (rodadas 8–11), detecta FASE dinamicamente
    CarregaTipagem = (caminho as text) as table =>
      let
        f = Excel.Workbook(File.Contents(caminho), null, true),
        o0 = Table.PromoteHeaders(f{[Item="Base Rep.",Kind="Sheet"]}[Data], [PromoteAllScalars=true]),
        o = Table.RenameColumns(
                o0,
                {
                    {"Clas. Loja", "Pot venda"},
                    {"Clas. loja", "Pot venda"},
                    {"Pot Venda",  "Pot venda"},
                    {"Pot venda ", "Pot venda"}
                },
                MissingField.Ignore
            ),
        // lista de colunas que sempre existem
        colTipos = {
            {"CANAL", type text}, {"FILIAL", Int64.Type}, {"FILIAL_NOME", type text},
            {"REGIAO", type text}, {"SKU", type text}, {"ARTIGO_COR", type text},
            {"PRODUTO", type text}, {"DESC_PRODUTO", type text}, {"COR", type text},
            {"TAM", type text}, {"TAM_GRADE", type text}, {"NEGOCIO", type text},
            {"PIRAMIDE", type text}, {"GENERO", type text}, {"IDADE_PRODUTO", type text},
            {"GRUPO_PRODUTO", type text}, {"LINHA", type text}, {"COLECAO", Int64.Type},
            {"VELOCIDADE_VENDA", type number}, {"LEADTIME", type number}, {"COBERTURA", Int64.Type},
            {"MINIMO", Int64.Type}, {"LOJA", Int64.Type}, {"TRANSITO", Int64.Type},
            {"RESERVADO", Int64.Type}, {"RESSUPRIR", Int64.Type}, {"DATA", type date},
            {"Estoque negativo", type logical}
        },
        // adiciona FASE se presente na tabela
        colTiposFinal = if List.Contains(Table.ColumnNames(o), "FASE")
                        then List.InsertRange(colTipos, List.Count(colTipos), {{"FASE", type text}})
                        else colTipos,
        t = Table.TransformColumnTypes(o, colTiposFinal)
      in
        t,

    // 3) Carrega cada rodada do Excel
    Tipo8  = CarregaTipagem("C:\\Users\\gabriel.thiago\\Downloads\\(Validação) 8ª rodada_20.05.xlsx"),
    Tipo9  = CarregaTipagem("C:\\Users\\gabriel.thiago\\Downloads\\(Validação) 9ª rodada_28.05_Fase 2.xlsx"),
    Tipo10 = CarregaTipagem("C:\\Users\\gabriel.thiago\\Downloads\\(Validação) 10ª rodada_04.06.xlsx"),
    Tipo11 = CarregaTipagem("C:\\Users\\gabriel.thiago\\Downloads\\(Validação) 11ª rodada_10.06.xlsx"),

    // 4) Adiciona coluna FASE vazia apenas onde não existe
    TipoFullF = Table.AddColumn(TipoFull, "FASE", each null, type text),
    Tipo8F    = Table.AddColumn(Tipo8,   "FASE", each null, type text),

    // 5) Alinha colunas e empilha as 11 rodadas
    A8   = Table.SelectColumns(Tipo8F,  Table.ColumnNames(TipoFullF), MissingField.Ignore),
    A9   = Table.SelectColumns(Tipo9,   Table.ColumnNames(TipoFullF), MissingField.Ignore),
    A10  = Table.SelectColumns(Tipo10,  Table.ColumnNames(TipoFullF), MissingField.Ignore),
    A11  = Table.SelectColumns(Tipo11,  Table.ColumnNames(TipoFullF), MissingField.Ignore),
    BaseAll    = Table.Combine({ TipoFullF, A8, A9, A10, A11 }),
    BaseNoNull = Table.SelectRows(BaseAll, each [DATA] <> null),

    // 6) Filtra só filiais com todas as 11 datas
    Datas      = List.Distinct(BaseNoNull[DATA]),
    TotalDatas = List.Count(Datas),
    Qtd        = Table.Group(BaseNoNull, {"FILIAL"}, {{"Cnt", each List.Count(List.Distinct([DATA])), Int64.Type}}),
    FilOK      = Table.SelectRows(Qtd, each [Cnt] = TotalDatas),
    BaseFilt   = Table.Join(BaseNoNull, "FILIAL", FilOK, "FILIAL", JoinKind.Inner),

    // 7) Cria coluna auxiliar de rodada (1–11)
    BaseRod = Table.AddColumn(
      BaseFilt,
      "Qtd de rodadas",
      each
        if [DATA] = #date(2025, 4, 2)  then 1
        else if [DATA] = #date(2025, 4, 9)  then 2
        else if [DATA] = #date(2025, 4, 16) then 3
        else if [DATA] = #date(2025, 4, 23) then 4
        else if [DATA] = #date(2025, 4, 29) then 5
        else if [DATA] = #date(2025, 5, 7)  then 6
        else if [DATA] = #date(2025, 5, 14) then 7
        else if [DATA] = #date(2025, 5, 20) then 8
        else if [DATA] = #date(2025, 5, 29) then 9
        else if [DATA] = #date(2025, 6, 10) then 11
        else 10,
      Int64.Type
    ),

    // 8) Lookup de fases (rodadas 9–11)
    BaseFase = Table.Combine({ Tipo9, Tipo10, Tipo11 }),
    FaseSim  = Table.Distinct(Table.SelectColumns(BaseFase, {"FILIAL","ARTIGO_COR","DATA","FASE"}), {"FILIAL","ARTIGO_COR","DATA"}),

    // 9) Merge e expand sem duplicar linhas
    M = Table.NestedJoin(BaseRod, {"FILIAL","ARTIGO_COR","DATA"}, FaseSim, {"FILIAL","ARTIGO_COR","DATA"}, "L", JoinKind.LeftOuter),
    E = Table.ExpandTableColumn(M, "L", {"FASE"}, {"FASE_9e11"}),
    SemOldFa = Table.RemoveColumns(E, {"FASE"}),
    ComFase  = Table.AddColumn(SemOldFa, "FASE", each if [Qtd de rodadas] <= 8 then "1ª Fase" else [FASE_9e11], type text),

    ResultadoFinal = Table.RemoveColumns(ComFase, {"FASE_9e11"}),
    #"Tipo Alterado" = Table.TransformColumnTypes(
        ResultadoFinal,
        {
          {"CONT_FALTA", Int64.Type}, {"CONT_EXCESSO", Int64.Type}, {"VOLUME_EXCESSO", Int64.Type},
          {"CONT_ALVO", Int64.Type}, {"VOLUME_FALTA", Int64.Type}, {"CONT_RUPTURA_RESSUP", Int64.Type},
          {"CONT_RUPTURA", Int64.Type}, {"ALVO", Int64.Type}, {"EST_TOTAL", Int64.Type},
          {"EST_DISP", Int64.Type}, {"RESSUPRIR", Int64.Type}, {"NECESSIDADE", Int64.Type},
          {"Qtd de rodadas", Int64.Type}, {"Pot venda", type text}
        }
    ),
    #"Valor Substituído" = Table.ReplaceValue(#"Tipo Alterado","Fase 1","1ª Fase",Replacer.ReplaceText,{"FASE"})
in
    #"Valor Substituído"
