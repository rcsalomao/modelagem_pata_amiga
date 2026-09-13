-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- >>> ESCREVA AQUI a consulta da P1
select
	dl.porte,
	avg(dias_integracao_separacao) as integracao_separacao,
    avg(dias_separacao_nota) as separacao_nota,
    avg(dias_nota_despacho) as nota_despacho,
    avg(dias_despacho_entrega) as despacho_entrega,
    avg(dias_total_ate_entrega) as total_ate_entrega,
    (select avg(dias_total_ate_entrega) from fato_pedido) as total_ate_entrega_da_rede
from fato_pedido p
join dim_loja dl
on p.sk_loja = dl.sk_loja
group by dl.porte;

-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- >>> ESCREVA AQUI a consulta da P2
select
	dl.porte,
	dc.nome_categoria,
    round(sum(p.vl_liquido)) as faturamento,
	round(sum(p.vl_liquido) / (select sum(fp.vl_liquido) from fato_pedido fp join dim_loja dl2 on fp.sk_loja = dl2.sk_loja where dl.porte = dl2.porte), 2) as total_perc
from
	fato_pedido p
join dim_categoria dc
on p.sk_categoria = dc.sk_categoria
join dim_loja dl
on p.sk_loja = dl.sk_loja
group by dl.porte, dc.nome_categoria
order by porte desc, total_perc desc;

-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- >>> ESCREVA AQUI a consulta da P3
select
	p.houve_desconto,
    p.canal_pedido,
	round(avg(p.vl_liquido), 2) as ticket_medio,
    round(sum(p.vl_liquido) / (select sum(vl_liquido) from fato_pedido), 2) as faturamento_perc
from fato_pedido p
group by p.canal_pedido, p.houve_desconto
order by p.houve_desconto desc, avg(p.vl_liquido) desc;

-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- >>> ESCREVA AQUI a consulta da P4
select
	dp.nome_praca,
    round(sum(p.vl_liquido * b.fator_publico), 2) as vl_total,
    dp.domicilios_com_pet
from
	fato_pedido p
join dim_loja dl
on p.sk_loja = dl.sk_loja
join bridge_loja_praca b
on b.cod_loja = dl.cod_loja
join dim_praca dp
on b.sk_praca = dp.sk_praca
group by dp.nome_praca, dp.domicilios_com_pet
order by vl_total desc;

-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- >>> ESCREVA AQUI as consultas da P5

-- P5a
select
	dl.nome_loja,
	sum(p.qt_itens) as qtd_itens,
	dl.populacao_cidade as populacao,
	round(1000 * sum(p.qt_itens) / dl.populacao_cidade, 2) as qtd_itens_por_mil,
    avg(p.dias_total_ate_entrega) as tempo_entrega_medio
from
	fato_pedido p
join dim_loja dl
on p.sk_loja = dl.sk_loja
group by dl.nome_loja, dl.populacao_cidade
order by proporcao desc;

-- P5b
select
	dl.faixa_franquia,
	sum(p.vl_liquido) as faturamento,
    sum(p.vl_liquido) / (select round(sum(vl_liquido), 2) from fato_pedido) as percentual
from fato_pedido p
join dim_loja dl
on p.sk_loja = dl.sk_loja
group by dl.faixa_franquia
order by faturamento desc;

-- P5c
select
	a.r as sem_loja, 
    b.r as nao_entregados,
    c.r as sem_itens,
    d.r as sem_valores
from (select count(*) as r from fato_pedido where sk_loja = -1) a
join (select count(*) as r from fato_pedido where sk_tempo_entrega = -1) b
join (select count(*) as r from fato_pedido where qt_itens is null) c
join (select count(*) as r from fato_pedido where vl_liquido is null) d;
