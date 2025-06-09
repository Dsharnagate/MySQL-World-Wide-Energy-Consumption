Create Database Energy_Consumption;
Use Energy_Consumption;

Select * from consum_3;
Select * from country_3;
Select * from population_3;
Select * from emission_3;
Select * from gdp_3;
Select * from production_3;

ALTER TABLE country_3 
MODIFY COLUMN CID VARCHAR(10) NOT NULL,
MODIFY COLUMN Country VARCHAR(100) NOT NULL,
ADD PRIMARY KEY (CID),
ADD UNIQUE (Country);

-- For emission_3 table
ALTER TABLE emission_3 
MODIFY COLUMN country VARCHAR(100) NOT NULL,
ADD CONSTRAINT fk_emission_country 
FOREIGN KEY (country) REFERENCES country_3(Country);

-- For population_3 table
ALTER TABLE population_3 
MODIFY COLUMN countries VARCHAR(100) NOT NULL,
ADD CONSTRAINT fk_population_country 
FOREIGN KEY (countries) REFERENCES country_3(Country);

-- For production_3 table
ALTER TABLE production_3 
MODIFY COLUMN country VARCHAR(100) NOT NULL,
ADD CONSTRAINT fk_production_country 
FOREIGN KEY (country) REFERENCES country_3(Country);

-- For gdp_3 table
ALTER TABLE gdp_3 
MODIFY COLUMN Country VARCHAR(100) NOT NULL,
ADD CONSTRAINT fk_gdp_country 
FOREIGN KEY (Country) REFERENCES country_3(Country);

-- For consum_3 table (assuming this is the consumption table)
ALTER TABLE consum_3 
MODIFY COLUMN country VARCHAR(100) NOT NULL,
ADD CONSTRAINT fk_consumption_country 
FOREIGN KEY (country) REFERENCES country_3(Country);

-- Check for any remaining foreign key violations
SELECT e.country 
FROM emission_3 e
LEFT JOIN country_3 c ON e.country = c.Country
WHERE c.Country IS NULL;

-- What is the total emission per country for the most recent year available?
SELECT 
    e.country,
    e.emission
FROM emission_3 e
JOIN (
    SELECT country, MAX(year) AS max_year
    FROM emission_3
    GROUP BY country
) latest ON e.country = latest.country AND e.year = latest.max_year
ORDER BY e.emission DESC;

-- What are the top 5 countries by GDP in the most recent year?
SELECT 
    g.Country,
    g.Value AS GDP
FROM gdp_3 g
JOIN (
    SELECT MAX(year) AS max_year 
    FROM gdp_3
) latest ON g.year = latest.max_year
ORDER BY g.Value DESC
LIMIT 5;

-- Compare energy production and consumption by country and year. 
SELECT 
    p.country,
    p.year,
    p.energy,
    p.production,
    c.consumption,
    (c.consumption - p.production) AS net_import_export
FROM production_3 p
JOIN consum_3 c ON p.country = c.country AND p.year = c.year AND p.energy = c.energy
ORDER BY p.country, p.year, p.energy;

-- Which energy types contribute most to emissions across all countries?
SELECT 
    e.energy_type,
    SUM(e.emission) AS total_emission
FROM emission_3 e
GROUP BY e.energy_type
ORDER BY total_emission DESC;

-- Trend Analysis Over Time

-- How have global emissions changed year over year?
SELECT 
    year,
    SUM(emission) AS global_emission,
    LAG(SUM(emission)) OVER (ORDER BY year) AS prev_year_emission,
    (SUM(emission) - LAG(SUM(emission)) OVER (ORDER BY year)) AS yoy_change
FROM emission_3
GROUP BY year
ORDER BY year;

-- GDP trend for each country
SELECT 
    Country,
    year,
    Value AS GDP,
    Value - LAG(Value) OVER (PARTITION BY Country ORDER BY year) AS yoy_change
FROM gdp_3
ORDER BY Country, year;

-- How has population growth affected total emissions in each country?
SELECT 
    e.country,
    e.year,
    e.emission,
    p.Value AS population,
    e.emission / p.Value AS emission_per_capita,
    (e.emission / p.Value) - LAG(e.emission / p.Value) OVER (PARTITION BY e.country ORDER BY e.year) AS per_capita_change
FROM emission_3 e
JOIN population_3 p ON e.country = p.countries AND e.year = p.year
ORDER BY e.country, e.year;

-- Has energy consumption increased or decreased over the years for major economies?
WITH major_economies AS (
    SELECT country 
    FROM gdp_3
    WHERE year = (SELECT MAX(year) FROM gdp_3)
    ORDER BY Value DESC 
    LIMIT 10
)
SELECT 
    c.country,  
    c.year,  
    SUM(c.consumption) AS total_consumption,  
    SUM(c.consumption) - LAG(SUM(c.consumption)) OVER (PARTITION BY c.country ORDER BY c.year) AS yoy_change
FROM consum_3 c
JOIN major_economies m ON c.country = m.country
GROUP BY c.country, c.year
ORDER BY c.country, c.year;

-- What is the average yearly change in emissions per capita for each country?
WITH per_capita AS (
    SELECT 
        e.country,
        e.year,
        e.per_capita_emission,
        e.per_capita_emission - LAG(e.per_capita_emission) OVER (PARTITION BY e.country ORDER BY e.year) AS yearly_change
    FROM emission_3 e
)
SELECT 
    country,
    AVG(yearly_change) AS avg_yearly_change
FROM per_capita
WHERE yearly_change IS NOT NULL
GROUP BY country
ORDER BY avg_yearly_change;

-- Ratio & Per Capita Analysis
-- What is the emission-to-GDP ratio for each country by year?
SELECT 
    e.country,
    e.year,
    e.emission,
    g.Value AS GDP,
    e.emission / g.Value AS emission_gdp_ratio
FROM emission_3 e
JOIN gdp_3 g ON e.country = g.Country AND e.year = g.year
ORDER BY emission_gdp_ratio DESC;

-- What is the energy consumption per capita for each country over the last decade?
SELECT 
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption,
    p.Value AS population,
    SUM(c.consumption) / p.Value AS consumption_per_capita
FROM consum_3 c
JOIN population_3 p ON c.country = p.countries AND c.year = p.year
WHERE c.year >= YEAR(CURDATE()) - 10
GROUP BY c.country, c.year, p.Value
ORDER BY c.country, c.year;

-- How does energy production per capita vary across countries?
SELECT 
    p.country,
    p.year,
    SUM(p.production) AS total_production,
    pop.Value AS population,
    SUM(p.production) / pop.Value AS production_per_capita
FROM production_3 p
JOIN population_3 pop ON p.country = pop.countries AND p.year = pop.year
GROUP BY p.country, p.year, pop.Value
ORDER BY production_per_capita DESC;

-- Which countries have the highest energy consumption relative to GDP?
SELECT 
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption,
    g.Value AS GDP,
    SUM(c.consumption) / g.Value AS consumption_gdp_ratio
FROM consum_3 c
JOIN gdp_3 g ON c.country = g.Country AND c.year = g.year
GROUP BY c.country, c.year, g.Value
ORDER BY consumption_gdp_ratio DESC
LIMIT 10;

-- What is the correlation between GDP growth and energy production growth?
WITH gdp_growth AS (
    SELECT 
        Country,
        year,
        Value,
        (Value - LAG(Value) OVER (PARTITION BY Country ORDER BY year)) / LAG(Value) OVER (PARTITION BY Country ORDER BY year) AS gdp_growth_pct
    FROM gdp_3
),
production_growth AS (
    SELECT 
        country,
        year,
        SUM(production) AS total_production,
        (SUM(production) - LAG(SUM(production)) OVER (PARTITION BY country ORDER BY year)) / LAG(SUM(production)) OVER (PARTITION BY country ORDER BY year) AS production_growth_pct
    FROM production_3
    GROUP BY country, year
)
SELECT 
    g.Country,
    g.year,
    g.gdp_growth_pct,
    p.production_growth_pct
FROM gdp_growth g
JOIN production_growth p ON g.Country = p.country AND g.year = p.year
WHERE g.gdp_growth_pct IS NOT NULL AND p.production_growth_pct IS NOT NULL
ORDER BY g.Country, g.year;

-- Global Comparisons
-- What are the top 10 countries by population and how do their emissions compare?
WITH top_pop AS (
    SELECT 
        countries,
        Value AS population
    FROM population_3
    WHERE year = (SELECT MAX(year) FROM population_3)
    ORDER BY Value DESC
    LIMIT 10
)
SELECT 
    p.countries,
    p.population,
    e.emission,
    e.emission / p.population AS per_capita_emission
FROM top_pop p
LEFT JOIN emission_3 e ON p.countries = e.country AND e.year = (SELECT MAX(year) FROM emission_3 WHERE country = p.countries)
ORDER BY p.population DESC;

-- Which countries have improved (reduced) their per capita emissions the most over the last decade?
WITH per_capita_change AS (
    SELECT 
        country,
        FIRST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year) AS first_year,
        LAST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_year,
        (LAST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) - 
         FIRST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year)) / 
        FIRST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year) * 100 AS pct_change
    FROM emission_3
    WHERE year >= YEAR(CURDATE()) - 10
)
SELECT DISTINCT
    country,
    first_year,
    last_year,
    pct_change
FROM per_capita_change
ORDER BY pct_change ASC
LIMIT 10;

-- What is the global share (%) of emissions by country?
WITH global_emissions AS (
    SELECT 
        year,
        SUM(emission) AS total_global
    FROM emission_3
    GROUP BY year
)
SELECT 
    e.country,
    e.year,
    e.emission,
    ge.total_global,
    (e.emission / ge.total_global) * 100 AS global_share_pct
FROM emission_3 e
JOIN global_emissions ge ON e.year = ge.year
ORDER BY e.year, global_share_pct DESC;

-- What is the global average GDP, emission, and population by year?
WITH global_emissions AS (
    SELECT 
        year,
        SUM(emission) AS total_global
    FROM emission_3
    GROUP BY year
)
SELECT 
    e.country,
    e.year,
    e.emission,
    ge.total_global,
    (e.emission / ge.total_global) * 100 AS global_share_pct
FROM emission_3 e
JOIN global_emissions ge ON e.year = ge.year
ORDER BY e.year, global_share_pct DESC;