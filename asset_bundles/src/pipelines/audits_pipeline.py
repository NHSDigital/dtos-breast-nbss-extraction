import dlt
import sys
import os
from pyspark.sql import functions as F
from pyspark.sql.functions import col, to_date
from audits_cast import cast_subjects, cast_episodes

# -----------------------
#  Bronze tables for subjects and episodes
# -----------------------

SOURCE_PATH = "abfss://raw@bsrtestdatalake.dfs.core.windows.net/audits/20250523"
BRONZE_SCHEMA = spark.conf.get("pipeline.bronze_schema")
SILVER_SCHEMA = spark.conf.get("pipeline.silver_schema")
GOLD_SCHEMA = spark.conf.get("pipeline.gold_schema")
CATALOG     = "devs"


@dlt.table(
    name=f"{BRONZE_SCHEMA}.audit_subjects",
    comment="Raw audit_subjects ingested from ADLS via Auto Loader"
)
def bronze_subjects():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
        .option("pathGlobFilter", "audit_subjects")
        .load(SOURCE_PATH)
    )

@dlt.table(
    name=f"{BRONZE_SCHEMA}.audit_episodes",
    comment="Raw audit_episodes ingested from ADLS via Auto Loader"
)
def bronze_episodes():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
        .option("pathGlobFilter", "audit_episodes")
        .load(SOURCE_PATH)
    )

# -----------------------
#  Silver - clean, validate, and deduplicate
# -----------------------
# subject
@dlt.table(
    name=f"{SILVER_SCHEMA}.audit_subjects",
    comment="Cleaned, validated, and deduplicated audit_subjects"
)
@dlt.expect_or_drop("valid_nhs_number", "nhs_number IS NOT NULL")
def silver_subjects():
    return (
        cast_subjects(dlt.read_stream(f"{BRONZE_SCHEMA}.audit_subjects"))
        .withColumn("change_db_date_time", to_date(col("change_db_date_time")))
        .dropDuplicates(["nhs_number","change_db_date_time"])
    )


# episodes
@dlt.table(
    name=f"{SILVER_SCHEMA}.audit_episodes",
    comment="Cleaned, validated, and deduplicated audit_episodes"
)
@dlt.expect_or_drop("valid_nhs_number", "nhs_number IS NOT NULL")
@dlt.expect_or_drop("valid_episode_id", "episode_id IS NOT NULL")
def silver_episodes():
    return (
        cast_episodes(dlt.read_stream(f"{BRONZE_SCHEMA}.audit_episodes"))
        .withColumn("change_db_date_time", to_date(col("change_db_date_time")))
        .dropDuplicates(["nhs_number","episode_id"])
    )

# -----------------------
#  Gold - Aggregate for reporting
# -----------------------
@dlt.table(
    name= f"{GOLD_SCHEMA}.episodes_by_patient",
    comment="Total episodes per Patients",
)
def episodes_by_patient():
    return (
        dlt.read(f"{SILVER_SCHEMA}.audit_episodes")
        .groupBy("nhs_number")
        .agg({"nhs_number": "count"})
        .withColumnRenamed("count(nhs_number)", "episode_count")
    )


@dlt.table(
    name= f"{GOLD_SCHEMA}.subjects_to_episodes",
    comment="Join across subjects and episodes",
)
def subjects_to_episodes():
    df_episodes = dlt.read(f"{SILVER_SCHEMA}.audit_episodes")
    df_subjects = dlt.read(f"{SILVER_SCHEMA}.audit_subjects")
    return (
        df_subjects.alias("s")
        .join(df_episodes.alias("e"), on=[F.col("s.nhs_number") == F.col("e.nhs_number"), F.col("s.bso_organisation_code") == F.col("e.bso_organisation_code")], how="inner")
        .select(
            "e.nhs_number",
            "e.episode_id",
            "e.bso_organisation_code",
            "e.bso_batch_id",
            "e.episode_date",
            "e.episode_type",
            "e.appointment_made",
            "e.end_code",
            "e.end_code_last_updated",
            "e.end_point",
            "e.final_action_code",
            "e.call_recall_status_authorised_by",
            "e.reason_closed_code",
            "e.date_of_foa",
            "e.date_of_as",
            "e.early_recall_date",
            F.col("e.change_db_date_time").alias("episode_change_db_date_time"),
            "s.subject_postcode",
            "s.preferred_language",
            "s.gp_practice_code",
            "s.subject_status_code",
            F.col("s.change_db_date_time").alias("subject_change_db_date_time"),
        )
    )
