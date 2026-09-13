-- =====================================================================================
--  ARQUIVO 3:  AS DIMENSOES QUE VOCE PREENCHE
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 01-carga-staging.sql  e  02-dimensoes-prontas.sql
--
--  As tabelas ja existem, vazias, criadas no arquivo 02. Aqui voce as PREENCHE.
--  Sao duas dimensoes e uma ponte:
--      dim_categoria       o de-para das grafias
--      dim_praca           uma linha por praca de atendimento
--      bridge_loja_praca   a ligacao N:N entre loja e praca, com o rateio
--
--  Regras para as duas dimensoes:
--    * PK = surrogate key inteira (AUTO_INCREMENT)
--    * a chave natural (a grafia, o cod da praca) fica como atributo
--    * sempre a linha -1 = "Nao Informado", inserida ANTES do INSERT ... SELECT
--    * as tabelas stg_ NAO se alteram
--
--  Comandos: INSERT ... VALUES, INSERT ... SELECT, SELECT DISTINCT, JOIN,
--  GROUP BY, CASE WHEN, REPLACE, UPPER, TRIM, CAST, MAX
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  DIM_CATEGORIA        grao: UMA GRAFIA DA ORIGEM
-- =====================================================================================
--  Guarde a grafia CRUA em categoria_origem e a versao padronizada em
--  nome_categoria (uma linha por grafia; varias grafias podem apontar para o
--  mesmo nome). Depois a fato acha a linha por categoria_origem.
--  Insira primeiro a linha -1. No INSERT ... SELECT DISTINCT, um CASE traduz as
--  grafias em 7 categorias.
--  ATENCAO: a ordem do CASE importa - "Racao Medicamentosa" e Medicamento, entao
--  teste MED antes de RA. Compare em UPPER e use trechos SEM acento.

-- >>> ESCREVA AQUI: a linha -1 e o INSERT ... SELECT da dim_categoria

delete from dim_categoria;
insert into dim_categoria values
(-1, '', 'Nao informado', 'Nao informado');
alter table dim_categoria auto_increment = 1;
insert into dim_categoria (categoria_origem, nome_categoria, grupo_categoria)
select
    a.cat,
    case
        when upper(a.cat) like '%MED%' then 'Medicamento'
        when upper(a.cat) like '%PETISC%' then 'Petisco'
        when upper(a.cat) like '%RA%' then 'Racao'
        when upper(a.cat) like '%HIG%' then 'Higiene'
        when upper(a.cat) like '%BRINQ%' then 'Brinquedo'
        when upper(a.cat) like '%ACESS%' then 'Acessorio'
        when upper(a.cat) like '%SERV%' then 'Servico'
    end,
     case
        when upper(a.cat) like '%MED%' then 'Saude e Higiene'
        when upper(a.cat) like '%PETISC%' then 'Alimentacao'
        when upper(a.cat) like '%RA%' then 'Alimentacao'
        when upper(a.cat) like '%HIG%' then 'Saude e Higiene'
        when upper(a.cat) like '%BRINQ%' then 'Bem-estar'
        when upper(a.cat) like '%ACESS%' then 'Bem-estar'
        when upper(a.cat) like '%SERV%' then 'Bem-estar'
    end
from (
    select
        distinct(CategoriaProduto) as cat
    from stg_pedido
) a;


-- =====================================================================================
--  DIM_PRACA  +  BRIDGE_LOJA_PRACA
-- =====================================================================================
--  A stg_loja_praca tem 48 linhas: a mesma loja aparece uma vez por praca. Um
--  GROUP BY por CodPraca colapsa em 12 pracas. Colunas fora do GROUP BY precisam
--  de agregacao (MAX serve). domicilios_com_pet vem como '148.000': o ponto e
--  milhar, tire-o antes do CAST.

-- >>> ESCREVA AQUI: a linha -1 e o INSERT ... SELECT da dim_praca
delete from dim_praca;
insert into dim_praca values
(-1, '', 'Nao informado', 'Nao informado', 0);
alter table dim_praca auto_increment = 1;
insert into dim_praca (cod_praca, nome_praca, regional, domicilios_com_pet)
select
	CodPraca,
    NomePraca,
    Regional,
    cast(replace(DomiciliosComPet, '.', '') as signed)
from (
    select
        distinct(CodPraca),
        NomePraca,
        Regional,
        DomiciliosComPet
    from stg_loja_praca
) a;

-- -------------------------------------------------------------------------------------
--  A TABELA PONTE
-- -------------------------------------------------------------------------------------
--  Uma loja entrega em mais de uma praca (N:N) - por isso a ligacao vive numa
--  tabela propria, com o FATOR DE RATEIO dentro (os fatores de uma loja somam
--  1,00). A ponte usa o COD DA LOJA, nao a sk_loja.

-- >>> ESCREVA AQUI: o INSERT ... SELECT da bridge_loja_praca
delete from bridge_loja_praca;
insert into bridge_loja_praca
select
	CodLoja,
    sk_praca,
    cast(PercentualPublico as decimal(10,2))
from (
    select
        s.CodLoja,
        d.sk_praca,
        s.PercentualPublico
    from stg_loja_praca s
    left join dim_praca d
    on s.NomePraca = d.nome_praca
) a;

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 03").
-- =====================================================================================
