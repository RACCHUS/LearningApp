-- ============================================================================
-- Seed Migration: 12 Presentation Catalog Clusters, Source Releases & Primary Fields
-- Migration: 20260929000001_seed_catalog_clusters_and_fields.sql
-- ============================================================================

DO $$
DECLARE
  v_cip_rel_id uuid := 'a1000000-0000-0000-0000-000000000001';
  v_soc_rel_id uuid := 'a1000000-0000-0000-0000-000000000002';
  v_onet_rel_id uuid := 'a1000000-0000-0000-0000-000000000003';

  -- 12 Cluster UUIDs
  v_c1 uuid := 'c1000000-0000-0000-0000-000000000001';
  v_c2 uuid := 'c1000000-0000-0000-0000-000000000002';
  v_c3 uuid := 'c1000000-0000-0000-0000-000000000003';
  v_c4 uuid := 'c1000000-0000-0000-0000-000000000004';
  v_c5 uuid := 'c1000000-0000-0000-0000-000000000005';
  v_c6 uuid := 'c1000000-0000-0000-0000-000000000006';
  v_c7 uuid := 'c1000000-0000-0000-0000-000000000007';
  v_c8 uuid := 'c1000000-0000-0000-0000-000000000008';
  v_c9 uuid := 'c1000000-0000-0000-0000-000000000009';
  v_c10 uuid := 'c1000000-0000-0000-0000-000000000010';
  v_c11 uuid := 'c1000000-0000-0000-0000-000000000011';
  v_c12 uuid := 'c1000000-0000-0000-0000-000000000012';

  -- Core Field UUIDs
  v_f_cs uuid := 'f1000000-0000-0000-0000-000000000001';
  v_f_health uuid := 'f1000000-0000-0000-0000-000000000051';
  v_f_eng uuid := 'f1000000-0000-0000-0000-000000000014';
  v_f_biz uuid := 'f1000000-0000-0000-0000-000000000052';
  v_f_math uuid := 'f1000000-0000-0000-0000-000000000027';
  v_f_bio uuid := 'f1000000-0000-0000-0000-000000000026';
BEGIN
  -- 1. Source Releases
  insert into public.taxonomy_source_releases (id, source_system, release_version, release_date, license_name, attribution_text)
  values
    (v_cip_rel_id, 'nces_cip', '2020', '2020-01-01', 'US_Public_Domain', 'National Center for Education Statistics, U.S. Department of Education'),
    (v_soc_rel_id, 'bls_soc', '2018', '2018-01-01', 'US_Public_Domain', 'Bureau of Labor Statistics, U.S. Department of Labor'),
    (v_onet_rel_id, 'onet', 'onet_31_0', '2026-08-01', 'CC_BY_4_0', 'O*NET 31.0 Database, sponsored by USDOL/ETA')
  on conflict (source_system, release_version) do nothing;

  -- 2. Catalog Clusters (12 Presentation Clusters)
  insert into public.catalog_clusters (id, slug, title, description, emoji, icon, accent_color, sort_order, is_active)
  values
    (v_c1, 'computing-tech', 'Computing & Information Technology', 'Software development, cloud architecture, cybersecurity, and artificial intelligence.', '💻', 'computer', '#2563EB', 1, true),
    (v_c2, 'health-medicine', 'Health Professions & Medicine', 'Clinical healthcare, nursing, biomedical sciences, and pharmacology.', '🏥', 'local_hospital', '#DC2626', 2, true),
    (v_c3, 'engineering-tech', 'Engineering & Applied Technology', 'Mechanical, electrical, civil, and robotics engineering disciplines.', '⚙️', 'build', '#D97706', 3, true),
    (v_c4, 'business-finance', 'Business, Finance & Management', 'Corporate strategy, accounting, marketing, investment, and organizational leadership.', '📈', 'trending_up', '#059669', 4, true),
    (v_c5, 'physical-bio-sciences', 'Physical & Biological Sciences', 'Physics, chemistry, cellular biology, genetics, and ecology.', '🔬', 'science', '#7C3AED', 5, true),
    (v_c6, 'math-stats-data', 'Mathematics, Statistics & Data', 'Pure mathematics, predictive statistics, machine learning, and data analysis.', '📐', 'calculate', '#0891B2', 6, true),
    (v_c7, 'law-policy-security', 'Law, Public Policy & Security', 'Legal principles, criminal justice, public administration, and emergency services.', '⚖️', 'gavel', '#4B5563', 7, true),
    (v_c8, 'arts-design', 'Visual Arts, Performing Arts & Design', 'Digital design, animation, music, fine arts, and creative media.', '🎨', 'palette', '#DB2777', 8, true),
    (v_c9, 'social-sciences-education', 'Social Sciences, Psychology & Education', 'Cognitive psychology, sociology, pedagogy, and instructional design.', '🌍', 'psychology', '#4F46E5', 9, true),
    (v_c10, 'humanities-languages', 'Humanities, Languages & Literature', 'History, linguistics, world languages, philosophy, and cultural literature.', '📚', 'menu_book', '#B45309', 10, true),
    (v_c11, 'skilled-trades', 'Skilled Construction & Mechanical Trades', 'Electrical systems, HVAC, plumbing, precision manufacturing, and carpentry.', '🔨', 'construction', '#EA580C', 11, true),
    (v_c12, 'agriculture-environment', 'Agriculture, Natural Resources & Environment', 'Sustainable agriculture, horticulture, forestry, and environmental conservation.', '🌾', 'eco', '#16A34A', 12, true)
  on conflict (slug) do update set
    title = excluded.title,
    description = excluded.description,
    emoji = excluded.emoji,
    accent_color = excluded.accent_color,
    sort_order = excluded.sort_order;

  -- 3. Core Broad Fields
  insert into public.fields (id, name, slug, description, icon, field_kind, sort_order, is_active)
  values
    (v_f_cs, 'Computer and Information Sciences and Support Services', 'computer-science', 'Computing foundations, programming, algorithms, networks, and systems.', 'computer', 'broad_field', 1, true),
    (v_f_health, 'Health Professions and Related Programs', 'health-professions', 'Clinical medicine, nursing, therapies, diagnostic services, and medical sciences.', 'local_hospital', 'broad_field', 2, true),
    (v_f_eng, 'Engineering and Engineering Technologies', 'engineering', 'Application of scientific and mathematical principles to practical ends.', 'build', 'broad_field', 3, true),
    (v_f_biz, 'Business, Management, Marketing, and Related Support Services', 'business-management', 'Commerce, finance, marketing, accounting, and institutional leadership.', 'trending_up', 'broad_field', 4, true),
    (v_f_math, 'Mathematics and Statistics', 'mathematics-statistics', 'Theoretical and applied mathematics, numerical analysis, and statistical modeling.', 'calculate', 'broad_field', 5, true),
    (v_f_bio, 'Biological and Biomedical Sciences', 'biological-sciences', 'Living organisms, cellular biology, anatomy, genetics, and ecology.', 'science', 'broad_field', 6, true)
  on conflict (id) do update set
    field_kind = excluded.field_kind,
    name = excluded.name;

  -- 4. Map Broad Fields to Presentation Clusters
  insert into public.catalog_cluster_fields (cluster_id, field_id, sort_order)
  values
    (v_c1, v_f_cs, 1),
    (v_c2, v_f_health, 1),
    (v_c3, v_f_eng, 1),
    (v_c4, v_f_biz, 1),
    (v_c6, v_f_math, 1),
    (v_c5, v_f_bio, 1)
  on conflict (cluster_id, field_id) do nothing;

END $$;
