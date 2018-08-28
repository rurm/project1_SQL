--***************************** НАЧАЛО **************************
-- Запрос-1: Составим ТОП-10 самых комерчески успешных фильмов.
select title,revenue-budget as NPV from movies order by 2 desc limit 10;

-- Запрос-2: Составим ТОП-10 самых лучших фильмов по мнению пользователей.
select movies.title,round(100*av_mrk)/100 as mark from (select movieid,avg(rating) as av_mrk from ratings group by movieid order by 1 desc) as sample left join  movies on movieid=id order by 2 desc limit 10;

-- Создание представления - 1: Определим "попсовые" фильмы, неплохо заработавшие на старте, но позже получившие низкие оценки пользователей
drop view IF EXISTS pop_films;
CREATE VIEW pop_films AS select movies.title,round(100*av_mrk)/100 as mark, revenue-budget as NPV from (select movieid,avg(rating) as av_mrk from ratings group by movieid order by 1 desc) as sample left join  movies on movieid=id where av_mrk<2 order by 3 desc limit 10;
select * from pop_films order by 3 desc;

-- Создание представления - 2: А теперь найдем 10 самых недооцененные при старте проката фильмов, т.е. тех которые при выпуске не набрали значительных кассовых сборов, однака, в последующем набрали популярность среди пользователей.
drop view IF EXISTS good_films;
CREATE VIEW good_films AS select movies.title,round(100*av_mrk)/100 as mark, revenue-budget as NPV from (select movieid,avg(rating) as av_mrk from ratings group by movieid order by 1 desc) as sample left join  movies on movieid=id where av_mrk>4 order by 3 limit 10;
select * from good_films order by 2 desc;

-- Запрос-3: Посмотрим какие тэги у фильмов попавших в предыдущую выборку (только 3 первых).
select title, tags from (select movies.title,round(100*av_mrk)/100 as mark, revenue-budget as NPV, movies.id from (select movieid,avg(rating) as av_mrk from ratings group by movieid order by 1 desc) as sample left join  movies on movieid=id where av_mrk>4 order by 3 limit 3) as tab1 left join keywords on tab1.id=keywords.id;

-- Запрос-4: Найдем сооответствие ключей ссылок в таблица links и movies.
select movies.imdbid as movi_imdb_key, links.imdbid as link_imdb_key from movies join links on movies.id=links.movieid limit 10;
--*****************************
-- На примере стобца с бюджета рассмотрим простой статистический анализ на пренадлежность его к нормальному или лог нормальному распределению.

-- Запрос-5: Сначала создадим таблицу с минимальными и максимальными значениями budget, которые нам пригодятся при нормировке.
DROP TABLE IF EXISTS bdgt;
select min(budget) as b_mi, max(budget) as b_ma, min(log(budget)) as lg_b_mi, max(log(budget)) as lg_b_ma into bdgt from movies;

-- Запрос-6: Теперь создадим таблицу нормированных значений бюджета и логарифма бюджета.
DROP TABLE IF EXISTS norm1;
select (CAST(budget AS float)-(select b_mi from bdgt))/(select b_ma-b_mi from bdgt) as bg_norm,(log(CAST(budget AS float))-(select lg_b_mi from bdgt))/(select lg_b_ma-lg_b_mi from bdgt) as lg_bg_norm into norm1 from movies order by 1;

-- Запрос-7: Расчитаем метрики смещения среднего значения относительно крайних(m1 смещение среднего значения относительно минимума, m2 - относительно максимума). Так же расчитаем ошибку, как модуль разности между m1 и m2.
select (avg(bg_norm)-min(bg_norm)) as m1, (max(bg_norm)-avg(bg_norm)) as m2, abs((avg(bg_norm)-min(bg_norm))-(max(bg_norm)-avg(bg_norm))) as error from norm1;

-- Запрос-8: Теперь рассмотрим теже метрики для логарифма столбца бюджета.
select (avg(lg_bg_norm)-min(lg_bg_norm)) as m1_log, (max(lg_bg_norm)-avg(lg_bg_norm)) as m2_log, abs((avg(lg_bg_norm)-min(lg_bg_norm))-(max(lg_bg_norm)-avg(lg_bg_norm))) as error_log from norm1;
--
-- Как можно видеть в случаи с логарифмом метрика m1_log>m2_log (тогда как m1<m2), при этом error_log<error. Како можно сделать вывод из вышеперечисленного? Если статистика выборки достаточная, то 1) распределение параметра бюджет ближе к логнормальному чем к номальному 2) но величина ошибки даже для логнормального распределения достаточно велика (а именно log_m1 в 4.5 раза больше чем log_m2) это говорит об неоптимальности подобранного распределения.
-- Возможно полученный результат некорректен ввиду присутствия шумов. Тогда применим метод нормирования со смещенными границами для уменьшения влияния шумов и аномальных граничных значений области определения (смещение 5%).

-- Запрос-9: Для этого, сначала, создадим таблицу с индексами смещения.
DROP TABLE IF EXISTS n0;
select round(0.05*count(*)) as n_mi, round(0.95*count(*)) as n_ma into n0 from movies;

-- Запрос-10: Создадим таблицу с новыми границами нормирования для budget.
DROP TABLE IF EXISTS bdgt2;
select min(budget) as b_mi, max(budget) as b_ma, min(log(budget)) as lg_b_mi, max(log(budget)) as lg_b_ma into bdgt2 from (select budget, ROW_NUMBER() OVER (ORDER BY budget) as sort_num from movies order by budget) as sample where sort_num>=(select n_mi from n0) and sort_num<=(select n_ma from n0);

-- Запрос-11: Создадим новую таблицу нормированныйх значений бюджета и логарифма бюджета используя смещения.
DROP TABLE IF EXISTS norm2;
select ROW_NUMBER() OVER (ORDER BY budget) as sort_num, (CAST(budget AS float)-(select b_mi from bdgt2))/(select b_ma-b_mi from bdgt2) as bg_norm,(log(CAST(budget AS float))-(select lg_b_mi from bdgt2))/(select lg_b_ma-lg_b_mi from bdgt2) as lg_bg_norm into norm2 from movies order by 1;

-- Запрос-12: Расчитаем те же метрики что и ранее (а именно m1 смещение среднего относительно нижней границы, m2 - относительно верхней, и модуль разницы между m1 и m2).
select (avg(bg_norm)-(select bg_norm from norm2 where sort_num=(select n_mi from n0))) as m1, ((select bg_norm from norm2 where sort_num=(select n_ma from n0))-avg(bg_norm)) as m2, abs((avg(bg_norm)-(select bg_norm from norm2 where sort_num=(select n_mi from n0)))-((select bg_norm from norm2 where sort_num=(select n_ma from n0))-avg(bg_norm))) as error from norm2;

-- Запрос-13: А так же, все тоже самое для нормированного логарифма буджета.
select (avg(lg_bg_norm)-(select lg_bg_norm from norm2 where sort_num=(select n_mi from n0))) as m1_log, ((select lg_bg_norm from norm2 where sort_num=(select n_ma from n0))-avg(lg_bg_norm)) as m2_log, abs((avg(lg_bg_norm)-(select lg_bg_norm from norm2 where sort_num=(select n_mi from n0)))-((select lg_bg_norm from norm2 where sort_num=(select n_ma from n0))-avg(lg_bg_norm))) as error_log from norm2;

-- Как можно видеть ошибка уменьшилась по сравнению с методом стандартной нормировки и теперь error<error_log, причем общая величина ошибки значительно снизилась и теперь составляет всего 12.5%. Это может говорить о том что предположение о шумах в исходных данных было верным, а так, о том что, скорее всего, столбец budget пренадлежит к нормальному распределению.
--***************************** КОНЕЦ ******************************
-- Очистка памяти от представлений View
drop view IF EXISTS pop_films;
drop view IF EXISTS good_films;
