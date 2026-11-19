/*******************************************************************************
* Script Name: 01_Deploy_BankTransactions_DW.sql
* Purpose: Enterprise-grade deployment script for Bank Transactions DW
* Environment: SQL Server 2022 / SSMS 22
*******************************************************************************/

SET NOCOUNT ON;
PRINT '----------------------------------------------------------------';
PRINT 'Starting Bank Transactions Data Warehouse Deployment...';
PRINT '----------------------------------------------------------------';

-- STEP 1: Database Initialization
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'bank_transactions_dw')
BEGIN
    PRINT '-> Creating database [bank_transactions_dw]...';
    CREATE DATABASE bank_transactions_dw;
END
ELSE
BEGIN
    PRINT '-> Database [bank_transactions_dw] already exists.';
END;
GO

USE bank_transactions_dw;
GO

-- STEP 2: Schema Creation
PRINT '----------------------------------------------------------------';
PRINT 'Checking and creating schemas [stg] and [dw]...';
PRINT '----------------------------------------------------------------';

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg;');
    PRINT '-> Schema [stg] created successfully.';
END
ELSE
    PRINT '-> Schema [stg] already exists.';
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw')
BEGIN
    EXEC('CREATE SCHEMA dw;');
    PRINT '-> Schema [dw] created successfully.';
END
ELSE
    PRINT '-> Schema [dw] already exists.';
GO

-- STEP 3: Staging Tables Deployment
PRINT '----------------------------------------------------------------';
PRINT 'Deploying Staging Tables ([stg] schema)...';
PRINT '----------------------------------------------------------------';

-- Drop existing staging tables safely
DROP TABLE IF EXISTS stg.[transaction];
DROP TABLE IF EXISTS stg.account;
DROP TABLE IF EXISTS stg.account_type;
DROP TABLE IF EXISTS stg.branch;
DROP TABLE IF EXISTS stg.client;
DROP TABLE IF EXISTS stg.transaction_type;

CREATE TABLE stg.account_type (
    id NVARCHAR(50),
    description_type NVARCHAR(250)
);

CREATE TABLE stg.branch (
    id NVARCHAR(50),
    name NVARCHAR(50),
    location NVARCHAR(50),
    manager NVARCHAR(50)
);

CREATE TABLE stg.client (
    id NVARCHAR(50),
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    dob NVARCHAR(50),
    address NVARCHAR(50),
    age NVARCHAR(50),
    sex NVARCHAR(50),
    created_time NVARCHAR(50),
    contact_no NVARCHAR(50),
    work_no NVARCHAR(50)
);

CREATE TABLE stg.account (
    id NVARCHAR(50),
    balance_account NVARCHAR(50),
    status NVARCHAR(50),
    created_at NVARCHAR(50),
    deleted_at NVARCHAR(50),
    client_id NVARCHAR(50),
    account_type_id NVARCHAR(50),
    branch_id NVARCHAR(50)
);

CREATE TABLE stg.transaction_type (
    id NVARCHAR(50),
    [transaction_type] NVARCHAR(50),
    description NVARCHAR(150),
    transaction_fee NVARCHAR(50)
);

CREATE TABLE stg.[transaction] (
    id NVARCHAR(50),
    amount_transactions NVARCHAR(50),
    date_issued NVARCHAR(50),
    deposit NVARCHAR(50),
    withdraw NVARCHAR(50),
    transfer NVARCHAR(50),
    total_balance NVARCHAR(50),
    transactions_type_id NVARCHAR(50),
    source_account_id NVARCHAR(50),
    destination_account_id NVARCHAR(50)
);

PRINT '-> All 6 staging tables deployed successfully.';
GO

-- STEP 4: Star Schema Data Warehouse Tables Deployment
PRINT '----------------------------------------------------------------';
PRINT 'Deploying Star Schema Tables ([dw] schema)...';
PRINT '----------------------------------------------------------------';

DROP TABLE IF EXISTS dw.fact_transactions;
DROP TABLE IF EXISTS dw.dim_account;
DROP TABLE IF EXISTS dw.dim_client;
DROP TABLE IF EXISTS dw.dim_branch;
DROP TABLE IF EXISTS dw.dim_transaction_type;

CREATE TABLE dw.dim_account (
    account_key INT IDENTITY(1,1) PRIMARY KEY,
    account_id INT NOT NULL,
    account_type_id INT NOT NULL,
    account_type_description NVARCHAR(250) NOT NULL,
    account_status NVARCHAR(50) NOT NULL,
    opening_balance DECIMAL(18,2) NOT NULL,
    created_date DATETIME2(7) NOT NULL,
    deleted_date DATETIME2(7) NULL,
    is_deleted BIT NOT NULL
);

CREATE TABLE dw.dim_client (
    client_key INT IDENTITY(1,1) PRIMARY KEY,
    client_id INT NOT NULL,
    full_name NVARCHAR(101) NOT NULL,
    dob DATE NOT NULL,
    calculated_age INT NOT NULL,
    age_group VARCHAR(20) NOT NULL,
    sex NVARCHAR(50) NOT NULL,
    address NVARCHAR(50) NOT NULL,
    contact_no NVARCHAR(50) NOT NULL,
    work_no NVARCHAR(50) NOT NULL,
    client_since_date DATETIME2(7) NOT NULL
);

CREATE TABLE dw.dim_branch (
    branch_key INT IDENTITY(1,1) PRIMARY KEY,
    branch_id INT NOT NULL,
    branch_name NVARCHAR(50) NOT NULL,
    location NVARCHAR(50) NOT NULL,
    manager_name NVARCHAR(50) NOT NULL
);

CREATE TABLE dw.dim_transaction_type (
    transaction_type_key INT IDENTITY(1,1) PRIMARY KEY,
    transaction_type_id INT NOT NULL,
    transaction_type_name NVARCHAR(50) NOT NULL,
    description NVARCHAR(150) NOT NULL,
    standard_fee DECIMAL(18,2) NOT NULL
);

CREATE TABLE dw.fact_transactions (
    transaction_key INT IDENTITY(1,1) PRIMARY KEY,
    transaction_id INT NOT NULL,
    source_account_key INT NOT NULL,
    destination_account_key INT NULL,
    client_key INT NOT NULL,
    branch_key INT NOT NULL,
    transaction_type_key INT NOT NULL,
    transaction_timestamp DATETIME2(7) NOT NULL,
    transaction_amount DECIMAL(18,2) NOT NULL,
    deposit_amount DECIMAL(18,2) NOT NULL,
    withdraw_amount DECIMAL(18,2) NOT NULL,
    transfer_amount DECIMAL(18,2) NOT NULL,
    fee_amount DECIMAL(18,2) NOT NULL,
    post_transaction_balance DECIMAL(18,2) NULL
);

PRINT '-> All star schema dimension and fact tables deployed successfully.';
GO

-- STEP 5: ETL Transformation Stored Procedure Deployment
PRINT '----------------------------------------------------------------';
PRINT 'Deploying ETL Stored Procedure [dw].[sp_load_data_warehouse]...';
PRINT '----------------------------------------------------------------';
GO

CREATE OR ALTER PROCEDURE dw.sp_load_data_warehouse
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        PRINT 'ETL Started: Truncating/Reloading Data Warehouse...';

        -- Clear existing DW data safely
        DELETE FROM dw.fact_transactions;
        DELETE FROM dw.dim_account;
        DELETE FROM dw.dim_client;
        DELETE FROM dw.dim_branch;
        DELETE FROM dw.dim_transaction_type;

        -- 1. Load dim_branch
        INSERT INTO dw.dim_branch (branch_id, branch_name, location, manager_name)
        SELECT CAST(id AS INT), name, location, manager FROM stg.branch;

        -- 2. Load dim_transaction_type
        INSERT INTO dw.dim_transaction_type (transaction_type_id, transaction_type_name, description, standard_fee)
        SELECT CAST(id AS INT), [transaction_type], description, CAST(transaction_fee AS DECIMAL(18,2)) 
        FROM stg.transaction_type;

        -- 3. Load dim_client (handling age calculations)
        INSERT INTO dw.dim_client (client_id, full_name, dob, calculated_age, age_group, sex, address, contact_no, work_no, client_since_date)
        SELECT 
            CAST(id AS INT),
            CONCAT(first_name, ' ', last_name),
            CAST(dob AS DATE),
            DATEDIFF(YEAR, CAST(dob AS DATE), GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(dob AS DATE), GETDATE()), CAST(dob AS DATE)) > GETDATE() THEN 1 ELSE 0 END,
            CASE 
                WHEN DATEDIFF(YEAR, CAST(dob AS DATE), GETDATE()) < 26 THEN '18-25'
                WHEN DATEDIFF(YEAR, CAST(dob AS DATE), GETDATE()) < 36 THEN '26-35'
                WHEN DATEDIFF(YEAR, CAST(dob AS DATE), GETDATE()) < 51 THEN '36-50'
                ELSE '51+' 
            END,
            sex, address, contact_no, work_no,
            CAST(created_time AS DATETIME2(7))
        FROM stg.client;

        -- 4. Load dim_account (handling 'null' string values)
        INSERT INTO dw.dim_account (account_id, account_type_id, account_type_description, account_status, opening_balance, created_date, deleted_date, is_deleted)
        SELECT 
            CAST(a.id AS INT),
            CAST(a.account_type_id AS INT),
            ISNULL(t.description_type, 'Unknown'),
            a.status,
            CAST(a.balance_account AS DECIMAL(18,2)),
            CAST(a.created_at AS DATETIME2(7)),
            CAST(NULLIF(a.deleted_at, 'null') AS DATETIME2(7)),
            CASE WHEN LOWER(a.deleted_at) = 'null' OR a.deleted_at IS NULL THEN 0 ELSE 1 END
        FROM stg.account a
        LEFT JOIN stg.account_type t ON CAST(a.account_type_id AS INT) = CAST(t.id AS INT);

        -- 5. Load fact_transactions
        INSERT INTO dw.fact_transactions (
            transaction_id, source_account_key, destination_account_key, client_key, branch_key, 
            transaction_type_key, transaction_timestamp, transaction_amount, deposit_amount, 
            withdraw_amount, transfer_amount, fee_amount, post_transaction_balance
        )
        SELECT 
            CAST(f.id AS INT),
            ISNULL(da_src.account_key, -1),
            da_dest.account_key,
            ISNULL(dc.client_key, -1),
            ISNULL(db.branch_key, -1),
            ISNULL(dtt.transaction_type_key, -1),
            CAST(f.date_issued AS DATETIME2(7)),
            CAST(ISNULL(f.amount_transactions, 0) AS DECIMAL(18,2)),
            CAST(f.deposit AS DECIMAL(18,2)),
            CAST(f.withdraw AS DECIMAL(18,2)),
            CAST(ISNULL(f.transfer, 0) AS DECIMAL(18,2)),
            ISNULL(dtt.standard_fee, 0.00),
            CAST(NULLIF(f.total_balance, 'null') AS DECIMAL(18,2))
        FROM stg.[transaction] f
        INNER JOIN stg.account a_src ON CAST(f.source_account_id AS INT) = CAST(a_src.id AS INT)
        LEFT JOIN dw.dim_account da_src ON CAST(a_src.id AS INT) = da_src.account_id
        LEFT JOIN dw.dim_account da_dest ON CAST(NULLIF(f.destination_account_id, 'null') AS INT) = da_dest.account_id
        LEFT JOIN dw.dim_client dc ON CAST(a_src.client_id AS INT) = dc.client_id
        LEFT JOIN dw.dim_branch db ON CAST(a_src.branch_id AS INT) = db.branch_id
        LEFT JOIN dw.dim_transaction_type dtt ON CAST(f.transactions_type_id AS INT) = dtt.transaction_type_id;

        PRINT 'ETL Completed Successfully: Data Warehouse loaded.';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR OCCURRED DURING ETL LOAD:';
        PRINT ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

PRINT '----------------------------------------------------------------';
PRINT 'Deployment Script Finished Successfully!';
PRINT '----------------------------------------------------------------';