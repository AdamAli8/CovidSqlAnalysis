-- Imported excel data from https://ourworldindata.org/covid-deaths into SQL server 

SELECT *
FROM CovidProject..CovidVaccinations
WHERE location = 'Canada'
ORDER BY date desc;

-- data had duplicate entries on the date column. Approximately 5 extra entries per row.

SELECT DISTINCT date, continent, location, total_cases, new_cases, total_deaths, population
FROM CovidProject..CovidDeaths
ORDER BY location, date;

-- Total cases vs Total Deaths as a percentage

SELECT DISTINCT date, location, total_cases, total_deaths, ROUND((total_deaths/total_cases)*100,2) as DeathPercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
--where location = 'Canada'
ORDER BY location, date; 


-- Looking at Total Cases vs Population
-- Shows percentage of positive cases

SELECT DISTINCT date, location, population, total_cases, ROUND((total_cases/population)*100,2) as CasePercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
--where location = 'Canada'
ORDER BY location, date; 

-- Looking at countries with the highest cases of covid

SELECT  location, population, max(total_cases) as HighestCaseCount, ROUND(MAX((total_cases/population)*100),2) as CasePercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY CasePercentage DESC; 

-- Countries with the highest death count vs population

SELECT  location, population, max(cast(total_deaths as int)) as HighestDeathCount, ROUND(MAX((cast(total_deaths as int)/population)*100),2) as DeathPercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY DeathPercentage DESC; 

-- Continents with highest death count
-- Continent column showed incorrect data, some locations not classified to the correct continent (North America not counting Canada)
-- Confirmed via Google that these numbers are approximately correct

SELECT location, max(cast(total_deaths as int)) as HighestDeathCount
FROM CovidProject..CovidDeaths
WHERE continent IS NULL
AND location NOT IN ('Upper middle income', 'High income', 'Lower middle income', 'Low income', 'International')
GROUP BY location
ORDER BY HighestDeathCount DESC; 

-- Showing countries with highest death count

SELECT location, max(cast(total_deaths as int)) as HighestDeathCount
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
AND location NOT IN ('Upper middle income', 'High income', 'Lower middle income', 'Low income', 'International')
GROUP BY location
ORDER BY HighestDeathCount DESC; 

-- Global numbers

SELECT date, SUM(new_cases) as Total_cases, sum(cast(new_deaths as int)) as Total_deaths, ROUND((sum(cast(new_deaths as int))/sum(new_cases))*100,2) as DeathPercentage
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
group by date
ORDER BY 1, 2; 

-- Joining deaths table with vaccinations table
-- Showing Total population vs vaccinations

SELECT d.date, d.continent, d.location, d.population, v.new_vaccinations, SUM(CAST(v.new_vaccinations as bigint)) OVER (partition by d.location ORDER BY d.location, d.date) as total_vaccinations
FROM CovidProject..CovidDeaths d
JOIN CovidProject..CovidVaccinations v
	on d.location = v.location 
	AND d.date = v.date
--WHERE d.location = 'Canada'
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date;

-- Duplicate dates are misleading the data, causing aggregate functions to sum 5x the amount.
-- Using DISTINCT does not fix the issue, it only hides the duplicate data. Cleaning the data using a cte

--WITH cte AS (
--SELECT date, continent, location, total_cases, new_cases, total_deaths, new_deaths, population, ROW_NUMBER() OVER (PARTITION BY date, continent, location ORDER BY location, date) row_num
--FROM CovidProject..CovidDeaths)

--DELETE FROM cte WHERE row_num > 1

--SELECT * FROM cte
--ORDER BY location, date;

-- Issue with multiple dates is now fixed, numbers running correctly
-- Rolling_vaccinations column counts multiple doses. Multiple Google sources confirmed Canada's doses administered at 81 million as of march 30, 2022

-- Using previous query again to correctly see the rolling total vaccinations per country and calculate percentage of rolling vaccinations vs population

WITH vax_perc (continent, location, date, population,new_vaccinations, Rolling_vaccinations) AS
(
SELECT d.date, d.continent, d.location, d.population, v.new_vaccinations, SUM(CAST(v.new_vaccinations as bigint)) OVER (partition by d.location ORDER BY d.location, d.date) as Rolling_vaccinations
FROM CovidProject..CovidDeaths d
JOIN CovidProject..CovidVaccinations v
	on d.location = v.location 
	AND d.date = v.date
--WHERE d.location = 'Canada'
WHERE d.continent IS NOT NULL
--ORDER BY d.location, d.date;
)
SELECT *, ROUND((Rolling_vaccinations/population)*100,2) as Rolling_percentage
FROM vax_perc

--Creating a temp table

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rolling_vaccinations numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT d.date, d.continent, d.location, d.population, v.new_vaccinations, SUM(CAST(v.new_vaccinations as bigint)) OVER (partition by d.location ORDER BY d.location, d.date) as Rolling_vaccinations
FROM CovidProject..CovidDeaths d
JOIN CovidProject..CovidVaccinations v
	on d.location = v.location 
	AND d.date = v.date
--WHERE d.location = 'Canada'
WHERE d.continent IS NOT NULL
--ORDER BY d.location, d.date;

SELECT *, ROUND((Rolling_vaccinations/population)*100,2) as Rolling_percentage
FROM #PercentPopulationVaccinated

-- Creating Views for visualisations 
-- vaccination percentage view

Create View PercentPopulationVaccinated as 
SELECT d.date, d.continent, d.location, d.population, v.new_vaccinations, SUM(CAST(v.new_vaccinations as bigint)) OVER (partition by d.location ORDER BY d.location, d.date) as Rolling_vaccinations
FROM CovidProject..CovidDeaths d
JOIN CovidProject..CovidVaccinations v
	on d.location = v.location 
	AND d.date = v.date
--WHERE d.location = 'Canada'
WHERE d.continent IS NOT NULL
--ORDER BY d.location, d.date;

-- Global Death Percentage View

CREATE VIEW deathPercentage as 
SELECT date, SUM(new_cases) as Total_cases, sum(cast(new_deaths as int)) as Total_deaths, ROUND((sum(cast(new_deaths as int))/sum(new_cases))*100,2) as DeathPercentage
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
group by date
--ORDER BY 1, 2

-- Death Percentage per country View

CREATE VIEW countryDeaths AS
SELECT date, location, population, max(cast(total_deaths as int)) as HighestDeathCount, ROUND(MAX((cast(total_deaths as int)/population)*100),2) as DeathPercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, date, population
--ORDER BY location, date DESC

-- Case percentage per country View

CREATE VIEW countryCasePercentage AS 
SELECT DISTINCT date, location, population, total_cases, ROUND((total_cases/population)*100,2) as CasePercentage 
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
--where location = 'Canada'
--ORDER BY location, date

