from pyspark.sql import functions as F

DATE_FMT = "yyyy-MM-dd"
TS_FMT   = "yyyy-MM-dd HH:mm:ss"

def cast_subjects(df):
    return (
        df
        .withColumn("nhs_number",            F.regexp_replace(F.col("nhs_number"), r"\D", "").cast("long"))
        .withColumn("superseded_nhs_number", F.col("superseded_nhs_number").cast("long"))
        .withColumn("removal_reason",        F.col("removal_reason").cast("long"))
        .withColumn("change_db_date_time",   F.to_timestamp(F.col("change_db_date_time"), TS_FMT))
        .withColumn("early_recall_date",              F.to_date(F.col("early_recall_date"),              DATE_FMT))
        .withColumn("removal_date",                   F.to_date(F.col("removal_date"),                   DATE_FMT))
        .withColumn("next_test_due_date",             F.to_date(F.col("next_test_due_date"),             DATE_FMT))
        .withColumn("latest_invitation_date",         F.to_date(F.col("latest_invitation_date"),         DATE_FMT))
        .withColumn("higher_risk_next_test_due_date", F.to_date(F.col("higher_risk_next_test_due_date"), DATE_FMT))
        .withColumn("hr_recall_due_date",             F.to_date(F.col("hr_recall_due_date"),             DATE_FMT))
        .withColumn("date_irradiated",                F.to_date(F.col("date_irradiated"),                DATE_FMT))
        .withColumn("is_higher_risk",        F.col("is_higher_risk").cast("boolean"))
        .withColumn("is_higher_risk_active", F.col("is_higher_risk_active").cast("boolean"))
        .withColumn("bso_organisation_code",            F.col("bso_organisation_code").cast("string"))
        .withColumn("subject_status_code",              F.col("subject_status_code").cast("string"))
        .withColumn("ntdd_calculation_method",          F.col("ntdd_calculation_method").cast("string"))
        .withColumn("preferred_language",               F.col("preferred_language").cast("string"))
        .withColumn("gp_practice_code",                 F.col("gp_practice_code").cast("string"))
        .withColumn("reason_for_ceasing_code",          F.col("reason_for_ceasing_code").cast("string"))
        .withColumn("higher_risk_referral_reason_code", F.col("higher_risk_referral_reason_code").cast("string"))
        .withColumn("gene_code",                        F.col("gene_code").cast("string"))
        .withColumn("subject_postcode",                 F.col("subject_postcode").cast("string"))
    )


def cast_episodes(df):
    return (
        df
        .withColumn("nhs_number",       F.regexp_replace(F.col("nhs_number"), r"\D", "").cast("long"))
        .withColumn("episode_id",       F.col("episode_id").cast("long"))
        .withColumn("appointment_made", F.col("appointment_made").cast("boolean"))
        .withColumn("date_of_foa",      F.to_date(F.col("date_of_foa"),       DATE_FMT))
        .withColumn("date_of_as",       F.to_date(F.col("date_of_as"),        DATE_FMT))
        .withColumn("episode_date",     F.to_date(F.col("episode_date"),       DATE_FMT))
        .withColumn("early_recall_date",F.to_date(F.col("early_recall_date"),  DATE_FMT))
        .withColumn("change_db_date_time",   F.to_timestamp(F.col("change_db_date_time"),   TS_FMT))
        .withColumn("end_code_last_updated", F.to_timestamp(F.col("end_code_last_updated"), TS_FMT))
        .withColumn("episode_type",                     F.col("episode_type").cast("string"))
        .withColumn("end_code",                         F.col("end_code").cast("string"))
        .withColumn("call_recall_status_authorised_by", F.col("call_recall_status_authorised_by").cast("string"))
        .withColumn("bso_organisation_code",            F.col("bso_organisation_code").cast("string"))
        .withColumn("bso_batch_id",                     F.col("bso_batch_id").cast("string"))
        .withColumn("reason_closed_code",               F.col("reason_closed_code").cast("string"))
        .withColumn("end_point",                        F.col("end_point").cast("string"))
        .withColumn("final_action_code",                F.col("final_action_code").cast("string"))
    )
