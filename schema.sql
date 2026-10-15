-- PostgreSQL schema proposal for the production edition.
-- The browser prototype does not execute this file; it documents the server-backed data model.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  academic_year TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Africa/Mogadishu',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner','admin','scheduler','viewer')),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (school_id, email)
);

CREATE TABLE teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  staff_code TEXT,
  full_name TEXT NOT NULL,
  max_periods_per_day SMALLINT NOT NULL DEFAULT 5 CHECK (max_periods_per_day > 0),
  max_periods_per_week SMALLINT NOT NULL DEFAULT 24 CHECK (max_periods_per_week > 0),
  active BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (school_id, staff_code)
);

CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  short_code TEXT,
  requires_special_room BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (school_id, name),
  UNIQUE (school_id, short_code)
);

CREATE TABLE teacher_subjects (
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  PRIMARY KEY (teacher_id, subject_id)
);

CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  room_type TEXT NOT NULL DEFAULT 'Classroom',
  capacity INTEGER CHECK (capacity IS NULL OR capacity > 0),
  active BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (school_id, name)
);

CREATE TABLE class_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  grade_level TEXT,
  student_count INTEGER NOT NULL DEFAULT 0 CHECK (student_count >= 0),
  home_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (school_id, name)
);

CREATE TABLE school_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 6),
  display_name TEXT NOT NULL,
  UNIQUE (school_id, day_of_week)
);

CREATE TABLE periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  period_number SMALLINT NOT NULL CHECK (period_number > 0),
  starts_at TIME,
  ends_at TIME,
  is_break BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (school_id, period_number),
  CHECK (starts_at IS NULL OR ends_at IS NULL OR starts_at < ends_at)
);

CREATE TABLE teacher_unavailability (
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 6),
  period_id UUID NOT NULL REFERENCES periods(id) ON DELETE CASCADE,
  reason TEXT,
  PRIMARY KEY (teacher_id, day_of_week, period_id)
);

CREATE TABLE lesson_requirements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_group_id UUID NOT NULL REFERENCES class_groups(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE RESTRICT,
  periods_per_week SMALLINT NOT NULL CHECK (periods_per_week > 0),
  prefer_double_period BOOLEAN NOT NULL DEFAULT false,
  preferred_room_type TEXT,
  priority SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  UNIQUE (class_group_id, subject_id, teacher_id)
);

CREATE TABLE timetable_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  version_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','validated','published','archived')),
  generated_by UUID REFERENCES app_users(id) ON DELETE SET NULL,
  solver_name TEXT NOT NULL DEFAULT 'or-tools-cp-sat',
  objective_score NUMERIC,
  validation_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ
);

CREATE TABLE timetable_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timetable_version_id UUID NOT NULL REFERENCES timetable_versions(id) ON DELETE CASCADE,
  lesson_requirement_id UUID NOT NULL REFERENCES lesson_requirements(id) ON DELETE CASCADE,
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 6),
  period_id UUID NOT NULL REFERENCES periods(id) ON DELETE RESTRICT,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  locked BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (timetable_version_id, lesson_requirement_id, day_of_week, period_id)
);

-- These indexes speed up conflict queries. Application validation must enforce cross-table uniqueness.
CREATE INDEX idx_entries_version_day_period ON timetable_entries(timetable_version_id, day_of_week, period_id);
CREATE INDEX idx_entries_requirement ON timetable_entries(lesson_requirement_id);
CREATE INDEX idx_requirements_class ON lesson_requirements(class_group_id);
CREATE INDEX idx_requirements_teacher ON lesson_requirements(teacher_id);

CREATE TABLE exam_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  exam_date DATE NOT NULL,
  period_id UUID NOT NULL REFERENCES periods(id) ON DELETE RESTRICT,
  class_group_id UUID NOT NULL REFERENCES class_groups(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  duration_minutes SMALLINT NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 15 AND 300),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_exam_date_period ON exam_events(school_id, exam_date, period_id);

CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY,
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  before_data JSONB,
  after_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
