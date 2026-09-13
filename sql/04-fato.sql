-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

-- >>> ESCREVA AQUI o INSERT INTO fato_pedido (...) SELECT ... FROM stg_pedido ...
--
--  Roteiro das colunas:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a data no formato AAAAMMDD.
--    Monte com CAST(DATE_FORMAT(<a data>, '%Y%m%d') AS SIGNED). A data do PEDIDO
--    vem no formato americano com AM/PM: a mascara e '%m/%d/%Y %h:%i %p'
--    (STR_TO_DATE). Usar '%d/%m/%Y' NAO da erro - ela devolve NULL e datas
--    erradas em silencio, que e pior. Os marcos da entrega ja vem em ISO:
--    DATE() basta. Entrega em branco -> -1.
--
--  * sk_loja, sk_categoria: vem de LEFT JOIN; se nao achou par, -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpe o nome no ON. REPLACE tira '/SC' e o espaco
--    duplo; um CASE resolve 3 grafias (digitacao, apelido, abreviacao). Acento e
--    maiuscula nao atrapalham: a collation padrao do MySQL trata 'Timbo', 'TIMBO'
--    e 'Timbo' com acento como o mesmo texto.
--
--  * CATEGORIA (LEFT JOIN dim_categoria): uma linha so -
--    ON dc.categoria_origem = p.`CategoriaProduto`.
--
--  * houve_desconto e canal_pedido: padronize com CASE e grave na PROPRIA fato
--    (nao ha dimensao para eles). O de-para completo dos dois campos esta no
--    ENUNCIADO, na secao 7 ("Como padronizar o desconto e o canal").
--    A ordem importa: 'WHATSAPP' contem 'APP',
--    entao teste WHATS antes de APP.
--
--  * dinheiro e itens: '' e '-' viram NULL; tire "R$" e trate o milhar.
--
--  * os lags em dias: DATEDIFF(<fim>, <inicio>). Etapa nao cumprida grava NULL,
--    nunca 0. Use DATE() em volta da integracao (ela tem hora).

delete from fato_pedido;
alter table fato_pedido auto_increment = 1;
insert into fato_pedido (
	`numero_pedido`,
	`sk_tempo_pedido`,
	`sk_tempo_entrega`,
	`sk_loja`,
	`sk_categoria`,
	`houve_desconto`,
	`canal_pedido`,
	`dt_pedido`,
	`qt_itens`,
	`vl_liquido`,
	`dias_integracao_separacao`,
	`dias_separacao_nota`,
	`dias_nota_despacho`,
	`dias_despacho_entrega`,
	`dias_total_ate_entrega`
)
select
    p.NumeroPedido as numero_pedido,
    cast(date_format(str_to_date(p.DtHoraPedido, '%m/%d/%Y %h:%i %p'), '%Y%m%d') as signed) as sk_tempo_pedido,
    if(p.DtEntregaCliente = '', -1, cast(date_format(date(p.DtEntregaCliente), '%Y%m%d') as signed)) as sk_tempo_entrega,
    dl.sk_loja,
    dc.sk_categoria,
    case
        when upper(trim(p.HouveDesconto)) in ('S', 'SIM', '1', 'X', 'TRUE', 'V') then 'Sim'
        when upper(trim(p.HouveDesconto)) in ('N', 'NAO', '0', 'FALSE', 'F') then 'Nao'
        else 'Nao Informado'
    end as houve_desconto,
    case
        when upper(trim(p.CanalPedido)) like '%WHATS%' then 'WhatsApp'
        when upper(trim(p.CanalPedido)) like '%APP%' then 'App'
        when upper(trim(p.CanalPedido)) like '%SITE%' then 'Site'
        when upper(trim(p.CanalPedido)) like '%LOJA%' then 'Loja Fisica'
        when upper(trim(p.CanalPedido)) like '%TEL%' then 'Telefone'
        else 'Nao Informado'
    end as canal_pedido,
    str_to_date(p.DtHoraPedido, '%m/%d/%Y %h:%i %p') as dt_pedido,
    cast(nullif(nullif(p.`QTD.Itens`, '-'), '') as signed) as qt_itens,
    case
        when trim(replace(p.`ValorLiquidoPedido(R$)`,'R$','')) in ('','-') then null
        when p.`ValorLiquidoPedido(R$)` like '%,%' then cast(replace(replace(replace(replace(p.`ValorLiquidoPedido(R$)`,'R$',''),' ',''),'.',''),',','.') as decimal(15,2))
        else cast(replace(replace(p.`ValorLiquidoPedido(R$)`,'R$',''),' ','') as decimal(15,2))
    end as vl_liquido,
    datediff(if(p.`Dt Separacao Estoque` = '', null, date(p.`Dt Separacao Estoque`)), str_to_date(p.DtHoraIntegracaoERP, '%m/%d/%Y %h:%i %p')) as dias_integracao_separacao,
    datediff(if(p.DtNotaFiscal = '', null, date(p.DtNotaFiscal)), if(p.`Dt Separacao Estoque` = '', null, date(p.`Dt Separacao Estoque`))) as dias_separacao_nota,
    datediff(if(p.Dt_Despacho_Transportadora = '', null, date(p.Dt_Despacho_Transportadora)), if(p.DtNotaFiscal = '', null, date(p.DtNotaFiscal))) as dias_nota_despacho,
    datediff(if(p.DtEntregaCliente = '', null, date(p.DtEntregaCliente)), if(p.Dt_Despacho_Transportadora = '', null, date(p.Dt_Despacho_Transportadora))) as dias_despacho_entrega,
    datediff(if(p.DtEntregaCliente = '', null, date(p.DtEntregaCliente)), str_to_date(p.DtHoraPedido, '%m/%d/%Y %h:%i %p')) as dias_total_ate_entrega
from stg_pedido p
left join dim_loja dl
on
    case
        when upper(p.`Loja-Nome`) like '%BLUMENAL%' then replace(trim(replace(replace(upper(p.`Loja-Nome`), '/SC', ''), '  ', ' ')), 'BLUMENAL', 'BLUMENAU')
        when upper(p.`Loja-Nome`) like '%FLORIPA%' then replace(trim(replace(replace(upper(p.`Loja-Nome`), '/SC', ''), '  ', ' ')), 'FLORIPA', 'FLORIANOPOLIS')
        when upper(p.`Loja-Nome`) like '%JGUA%' then replace(trim(replace(replace(upper(p.`Loja-Nome`), '/SC', ''), '  ', ' ')), 'JGUA', 'JARAGUA')
        when p.`Loja-Nome` = '' then 'NAO INFORMADO'
        else trim(replace(replace(upper(p.`Loja-Nome`), '/SC', ''), '  ', ' '))
    end = dl.chave_loja
left join dim_categoria dc
on dc.categoria_origem = p.`CategoriaProduto`;


-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
