CREATE DATABASE university_management;
USE university_management;
-- 1. Core administrative tables
CREATE TABLE Departments (
  department_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE,
  code VARCHAR(10) NOT NULL UNIQUE,
  head_faculty_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Programs (
  program_id INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  code VARCHAR(20) NOT NULL,
  duration_months INT NOT NULL,
  degree VARCHAR(50) NOT NULL,
  CONSTRAINT fk_program_dept FOREIGN KEY (department_id) REFERENCES Departments(department_id)
);

CREATE TABLE Semesters (
  semester_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL, -- e.g., "Fall 2024"
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  UNIQUE (name, start_date)
);

-- 2. People
CREATE TABLE Faculty (
  faculty_id INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE,
  employee_no VARCHAR(50) UNIQUE,
  hire_date DATE,
  title VARCHAR(100),
  academic_rank VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_faculty_dept FOREIGN KEY (department_id) REFERENCES Departments(department_id)
);

CREATE TABLE Students (
  student_id INT AUTO_INCREMENT PRIMARY KEY,
  program_id INT NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  dob DATE,
  gender ENUM('M','F','Other') DEFAULT 'Other',
  national_id VARCHAR(50) UNIQUE,
  email VARCHAR(150) UNIQUE,
  enrollment_year YEAR NOT NULL,
  status ENUM('active','graduated','suspended','withdrawn') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_student_program FOREIGN KEY (program_id) REFERENCES Programs(program_id)
);

-- 3. Courses and curriculum
CREATE TABLE Courses (
  course_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL,
  title VARCHAR(200) NOT NULL,
  credits DECIMAL(3,1) NOT NULL,
  department_id INT NOT NULL,
  course_level ENUM('UG','PG') DEFAULT 'PG',
  description TEXT,
  CONSTRAINT fk_course_dept FOREIGN KEY (department_id) REFERENCES Departments(department_id),
  UNIQUE (code)
);

-- 4. Junction: Enrollments (Student <-> Course) — many-to-many
CREATE TABLE Enrollments (
  enrollment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  course_id INT NOT NULL,
  semester_id INT NOT NULL,
  status ENUM('enrolled','completed','dropped','incomplete') DEFAULT 'enrolled',
  grade VARCHAR(5), -- store letter or numeric string; analytics can convert
  grade_points DECIMAL(4,2), -- optional numeric grade for GPA calculations
  registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_enroll_student FOREIGN KEY (student_id) REFERENCES Students(student_id),
  CONSTRAINT fk_enroll_course FOREIGN KEY (course_id) REFERENCES Courses(course_id),
  CONSTRAINT fk_enroll_sem FOREIGN KEY (semester_id) REFERENCES Semesters(semester_id),
  UNIQUE (student_id, course_id, semester_id)
);
CREATE INDEX idx_enroll_student ON Enrollments(student_id);
CREATE INDEX idx_enroll_course ON Enrollments(course_id);
CREATE INDEX idx_enroll_sem_course ON Enrollments(semester_id, course_id);

-- 5. Junction: TeachingAssignments (Faculty <-> Course per Semester) — many-to-many
CREATE TABLE TeachingAssignments (
  assignment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  faculty_id INT NOT NULL,
  course_id INT NOT NULL,
  semester_id INT NOT NULL,
  role ENUM('Lead','CoInstructor','TA','Guest') DEFAULT 'Lead',
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ta_faculty FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id),
  CONSTRAINT fk_ta_course FOREIGN KEY (course_id) REFERENCES Courses(course_id),
  CONSTRAINT fk_ta_sem FOREIGN KEY (semester_id) REFERENCES Semesters(semester_id),
  UNIQUE (faculty_id, course_id, semester_id)
);
CREATE INDEX idx_ta_faculty ON TeachingAssignments(faculty_id);
CREATE INDEX idx_ta_course_sem ON TeachingAssignments(course_id, semester_id);

-- 6. Research projects + participants (many-to-many)
CREATE TABLE ResearchProjects (
  project_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(250) NOT NULL,
  lead_faculty_id INT,
  start_date DATE,
  end_date DATE,
  status ENUM('active','completed','paused') DEFAULT 'active',
  funding_source VARCHAR(200),
  CONSTRAINT fk_project_lead FOREIGN KEY (lead_faculty_id) REFERENCES Faculty(faculty_id)
);

CREATE TABLE ProjectParticipants (
  project_id INT NOT NULL,
  participant_type ENUM('student','faculty') NOT NULL,
  participant_id INT NOT NULL, -- if participant_type='student' => Students.student_id else Faculty.faculty_id
  role VARCHAR(100), -- e.g., 'Research Assistant', 'Co-PI'
  joined_at DATE,
  PRIMARY KEY (project_id, participant_type, participant_id),
  CONSTRAINT fk_pp_project FOREIGN KEY (project_id) REFERENCES ResearchProjects(project_id)
);
CREATE INDEX idx_pp_participant ON ProjectParticipants(participant_type, participant_id);

-- 7. Supervisions (Student <-> Faculty) — many-to-many (advisor / co-advisor)
CREATE TABLE Supervisions (
  student_id INT NOT NULL,
  faculty_id INT NOT NULL,
  start_date DATE,
  end_date DATE,
  role ENUM('Supervisor','Co-supervisor','Mentor') DEFAULT 'Supervisor',
  PRIMARY KEY (student_id, faculty_id),
  CONSTRAINT fk_superv_student FOREIGN KEY (student_id) REFERENCES Students(student_id),
  CONSTRAINT fk_superv_faculty FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
);
CREATE INDEX idx_superv_faculty ON Supervisions(faculty_id);

-- 8. Publications and authorship (many-to-many)
CREATE TABLE Publications (
  publication_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(400) NOT NULL,
  venue VARCHAR(200),
  pub_date DATE,
  doi VARCHAR(150),
  abstract TEXT
);

CREATE TABLE PublicationAuthors (
  publication_id INT NOT NULL,
  author_type ENUM('student','faculty','external') NOT NULL,
  author_id INT NOT NULL, -- student_id or faculty_id or external id (store external ids positive)
  author_order INT NOT NULL,
  PRIMARY KEY (publication_id, author_type, author_id),
  CONSTRAINT fk_pub_pub FOREIGN KEY (publication_id) REFERENCES Publications(publication_id)
);
CREATE INDEX idx_pub_author ON PublicationAuthors(author_type, author_id);

-- 9. Scholarships (and student scholarship junction)
CREATE TABLE Scholarships (
  scholarship_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  provider VARCHAR(200),
  amount DECIMAL(12,2),
  start_date DATE,
  end_date DATE
);

CREATE TABLE StudentScholarships (
  student_id INT NOT NULL,
  scholarship_id INT NOT NULL,
  awarded_date DATE NOT NULL,
  amount_received DECIMAL(12,2),
  remarks VARCHAR(400),
  PRIMARY KEY (student_id, scholarship_id, awarded_date),
  CONSTRAINT fk_ss_student FOREIGN KEY (student_id) REFERENCES Students(student_id),
  CONSTRAINT fk_ss_scholarship FOREIGN KEY (scholarship_id) REFERENCES Scholarships(scholarship_id)
);
CREATE INDEX idx_ss_student ON StudentScholarships(student_id);

-- 10. Internships and placements (many-to-many)
CREATE TABLE Internships (
  internship_id INT AUTO_INCREMENT PRIMARY KEY,
  company_name VARCHAR(200),
  position VARCHAR(200),
  start_date DATE,
  end_date DATE,
  stipend DECIMAL(12,2)
);

CREATE TABLE InternshipPlacements (
  internship_id INT NOT NULL,
  student_id INT NOT NULL,
  supervisor_company VARCHAR(200),
  start_date DATE,
  end_date DATE,
  evaluation VARCHAR(400),
  PRIMARY KEY (internship_id, student_id),
  CONSTRAINT fk_ip_intern FOREIGN KEY (internship_id) REFERENCES Internships(internship_id),
  CONSTRAINT fk_ip_student FOREIGN KEY (student_id) REFERENCES Students(student_id)
);

-- 11. Assessments (Course assessments) + StudentAssessments
CREATE TABLE Assessments (
  assessment_id INT AUTO_INCREMENT PRIMARY KEY,
  course_id INT NOT NULL,
  semester_id INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  max_marks DECIMAL(8,2) NOT NULL,
  weight_percent DECIMAL(5,2) NOT NULL,
  date DATE,
  CONSTRAINT fk_assess_course FOREIGN KEY (course_id) REFERENCES Courses(course_id),
  CONSTRAINT fk_assess_sem FOREIGN KEY (semester_id) REFERENCES Semesters(semester_id)
);

CREATE TABLE StudentAssessments (
  assessment_id INT NOT NULL,
  student_id INT NOT NULL,
  marks_obtained DECIMAL(8,2),
  graded_at TIMESTAMP,
  PRIMARY KEY (assessment_id, student_id),
  CONSTRAINT fk_sa_assessment FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id),
  CONSTRAINT fk_sa_student FOREIGN KEY (student_id) REFERENCES Students(student_id)
);
CREATE INDEX idx_sa_student ON StudentAssessments(student_id);

DESCRIBE Departments;

CREATE TABLE TeacherDepartment (
    teacher_id INT,
    department_id INT,
    assigned_date DATE,
    PRIMARY KEY (teacher_id, department_id),
    FOREIGN KEY (teacher_id) REFERENCES Teachers(TeacherID) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES Departments(department_id) ON DELETE CASCADE
);
SHOW TABLES;
CREATE INDEX idx_teacher
ON TeacherDepartment (teacher_id);
CREATE TABLE StudentCourse (
    StudentID INT,
    CourseID INT,
    EnrollmentDate DATE,
    PRIMARY KEY (StudentID, CourseID),
    FOREIGN KEY (StudentID) REFERENCES Students(StudentID) ON DELETE CASCADE,
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID) ON DELETE CASCADE
);


-- Adding Indexes for Optimization
CREATE INDEX idx_student_email ON Students(Email);
CREATE INDEX idx_teacher_email ON Teachers(Email);

-- Semester GPA per student (assuming grade_points stored per enrollment)
SELECT s.student_id, s.first_name, s.last_name, sem.name AS semester,
       SUM(e.grade_points * c.credits) / NULLIF(SUM(c.credits),0) AS semester_gpa
FROM Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Courses c ON e.course_id = c.course_id
JOIN Semesters sem ON e.semester_id = sem.semester_id
WHERE e.status = 'completed'
GROUP BY s.student_id, sem.semester_id
ORDER BY s.student_id, sem.start_date;

-- Average GPA by Program (last 3 years)
SELECT p.program_id, p.name,
       ROUND( SUM(e.grade_points * c.credits) / NULLIF(SUM(c.credits),0), 3) AS avg_gpa
FROM Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Courses c ON e.course_id = c.course_id
JOIN Programs p ON s.program_id = p.program_id
WHERE e.status = 'completed'
  AND e.registered_at >= DATE_SUB(CURDATE(), INTERVAL 3 YEAR)
GROUP BY p.program_id;

-- Students at-risk (GPA < 2.0 in most recent semester)
WITH recent_sem AS (
  SELECT semester_id FROM Semesters ORDER BY start_date DESC LIMIT 1
)
SELECT s.student_id, CONCAT(s.first_name,' ',s.last_name) AS student,
       SUM(e.grade_points * c.credits) / NULLIF(SUM(c.credits),0) AS gpa
FROM Enrollments e
JOIN recent_sem rs ON e.semester_id = rs.semester_id
JOIN Students s ON e.student_id = s.student_id
JOIN Courses c ON e.course_id = c.course_id
GROUP BY s.student_id
HAVING gpa < 2.0;

--  Top supervisors by number of graduated students
SELECT f.faculty_id, CONCAT(f.first_name,' ',f.last_name) AS faculty,
       COUNT(*) AS graduated_students_count
FROM Supervisions sv
JOIN Students s ON sv.student_id = s.student_id
JOIN Faculty f ON sv.faculty_id = f.faculty_id
WHERE s.status = 'graduated'
GROUP BY f.faculty_id
ORDER BY graduated_students_count DESC
LIMIT 20;

--  Course pass/fail rate using window functions
SELECT course_id, title,
       SUM(CASE WHEN grade_points >= 2.0 THEN 1 ELSE 0 END) AS passed,
       COUNT(*) AS total,
       ROUND(100 * SUM(CASE WHEN grade_points >= 2.0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pass_pct
FROM Enrollments e
JOIN Courses c ON e.course_id = c.course_id
WHERE e.status = 'completed'
GROUP BY course_id, title
ORDER BY pass_pct DESC;

-- Co-authorship network: number of shared publications between two students
SELECT a1.author_id AS author_a, a2.author_id AS author_b, COUNT(*) AS shared_pubs
FROM PublicationAuthors a1
JOIN PublicationAuthors a2
  ON a1.publication_id = a2.publication_id
WHERE a1.author_type = 'student' AND a2.author_type = 'student' AND a1.author_id < a2.author_id
GROUP BY a1.author_id, a2.author_id
ORDER BY shared_pubs DESC
LIMIT 50;

-- Enrollment trends per program per semester (time series)
SELECT p.program_id, p.name, sem.name AS semester, COUNT(DISTINCT e.student_id) AS enrolled_students
FROM Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Programs p ON s.program_id = p.program_id
JOIN Semesters sem ON e.semester_id = sem.semester_id
GROUP BY p.program_id, sem.semester_id
ORDER BY p.program_id, sem.start_date;


INSERT INTO Departments (name, code, head_faculty_id) VALUES
('Computer Science', 'CS', 1),
('Electrical Engineering', 'EE', 2),
('Mechanical Engineering', 'ME', 3),
('Mathematics', 'MATH', 4),
('Physics', 'PHY', 5),
('Chemistry', 'CHEM', 6),
('Business Administration', 'BUS', 7),
('Civil Engineering', 'CE', 8);

INSERT INTO Programs (department_id, name, code, duration_months, degree) VALUES
(1, 'MSc Computer Science', 'MSCS', 24, 'Masters'),
(1, 'PhD Computer Science', 'PHDCS', 48, 'Doctorate'),
(2, 'MSc Electrical Engineering', 'MSEE', 24, 'Masters'),
(3, 'MSc Mechanical Engineering', 'MSME', 24, 'Masters'),
(4, 'MSc Mathematics', 'MSMATH', 24, 'Masters'),
(5, 'PhD Physics', 'PHDPHY', 48, 'Doctorate'),
(6, 'MSc Chemistry', 'MSCHEM', 24, 'Masters'),
(7, 'MBA', 'MBA', 24, 'Masters');

INSERT INTO Semesters (name, start_date, end_date) VALUES
('Fall 2023', '2023-09-01', '2023-12-20'),
('Spring 2024', '2024-01-15', '2024-05-15'),
('Summer 2024', '2024-06-01', '2024-08-15'),
('Fall 2024', '2024-09-02', '2024-12-18'),
('Spring 2025', '2025-01-13', '2025-05-16'),
('Summer 2025', '2025-06-02', '2025-08-14'),
('Fall 2025', '2025-09-01', '2025-12-19'),
('Spring 2026', '2026-01-12', '2026-05-15');

INSERT INTO Faculty (department_id, first_name, last_name, email, employee_no, hire_date, title, academic_rank) VALUES
(1, 'John', 'Smith', 'john.smith@uni.edu', 'F001', '2015-08-15', 'Professor', 'Professor'),
(1, 'Sarah', 'Johnson', 'sarah.johnson@uni.edu', 'F002', '2018-03-01', 'Associate Professor', 'Associate Professor'),
(2, 'Michael', 'Chen', 'michael.chen@uni.edu', 'F003', '2016-07-20', 'Professor', 'Professor'),
(3, 'Emily', 'Davis', 'emily.davis@uni.edu', 'F004', '2019-01-10', 'Assistant Professor', 'Assistant Professor'),
(4, 'Robert', 'Wilson', 'robert.wilson@uni.edu', 'F005', '2014-09-05', 'Professor', 'Professor'),
(5, 'Lisa', 'Brown', 'lisa.brown@uni.edu', 'F006', '2017-11-15', 'Associate Professor', 'Associate Professor'),
(6, 'David', 'Miller', 'david.miller@uni.edu', 'F007', '2020-02-20', 'Assistant Professor', 'Assistant Professor'),
(7, 'Jennifer', 'Taylor', 'jennifer.taylor@uni.edu', 'F008', '2018-08-25', 'Associate Professor', 'Associate Professor');

INSERT INTO Students (program_id, first_name, last_name, dob, gender, national_id, email, enrollment_year, status) VALUES
(1, 'Alice', 'Johnson', '1998-05-15', 'F', 'NID001', 'alice.johnson@student.uni.edu', 2023, 'active'),
(1, 'Bob', 'Williams', '1999-08-22', 'M', 'NID002', 'bob.williams@student.uni.edu', 2023, 'active'),
(2, 'Carol', 'Martinez', '1995-12-10', 'F', 'NID003', 'carol.martinez@student.uni.edu', 2022, 'active'),
(3, 'Daniel', 'Lee', '1997-03-30', 'M', 'NID004', 'daniel.lee@student.uni.edu', 2023, 'active'),
(4, 'Emma', 'Garcia', '1998-07-18', 'F', 'NID005', 'emma.garcia@student.uni.edu', 2023, 'active'),
(5, 'Frank', 'Rodriguez', '1996-11-25', 'M', 'NID006', 'frank.rodriguez@student.uni.edu', 2022, 'graduated'),
(6, 'Grace', 'Anderson', '1994-09-08', 'F', 'NID007', 'grace.anderson@student.uni.edu', 2021, 'active'),
(7, 'Henry', 'Thomas', '1999-02-14', 'M', 'NID008', 'henry.thomas@student.uni.edu', 2023, 'active');

INSERT INTO Courses (code, title, credits, department_id, course_level, description) VALUES
('CS501', 'Advanced Algorithms', 3.0, 1, 'PG', 'Study of advanced algorithmic techniques and complexity analysis'),
('CS502', 'Machine Learning', 3.0, 1, 'PG', 'Introduction to machine learning algorithms and applications'),
('EE501', 'Digital Signal Processing', 3.0, 2, 'PG', 'Advanced topics in digital signal processing'),
('ME501', 'Advanced Thermodynamics', 3.0, 3, 'PG', 'Advanced concepts in thermodynamics and heat transfer'),
('MATH501', 'Advanced Calculus', 3.0, 4, 'PG', 'Multivariable calculus and vector analysis'),
('PHY601', 'Quantum Mechanics', 3.0, 5, 'PG', 'Graduate level quantum mechanics'),
('CHEM501', 'Organic Chemistry', 3.0, 6, 'PG', 'Advanced organic chemistry topics'),
('BUS501', 'Strategic Management', 3.0, 7, 'PG', 'Corporate strategy and business policy');

INSERT INTO Enrollments (student_id, course_id, semester_id, status, grade, grade_points) VALUES
(1, 1, 1, 'completed', 'A', 4.0),
(1, 2, 1, 'completed', 'A-', 3.7),
(2, 1, 1, 'completed', 'B+', 3.3),
(2, 2, 1, 'completed', 'A', 4.0),
(3, 3, 1, 'completed', 'B', 3.0),
(4, 4, 1, 'completed', 'A-', 3.7),
(5, 5, 1, 'completed', 'B+', 3.3),
(6, 6, 1, 'completed', 'A', 4.0);

INSERT INTO TeachingAssignments (faculty_id, course_id, semester_id, role) VALUES
(1, 1, 1, 'Lead'),
(2, 2, 1, 'Lead'),
(3, 3, 1, 'Lead'),
(4, 4, 1, 'Lead'),
(5, 5, 1, 'Lead'),
(6, 6, 1, 'Lead'),
(7, 7, 1, 'Lead'),
(8, 8, 1, 'Lead');

INSERT INTO ResearchProjects (title, lead_faculty_id, start_date, end_date, status, funding_source) VALUES
('AI for Healthcare', 1, '2023-01-15', '2025-01-15', 'active', 'National Science Foundation'),
('Renewable Energy Systems', 3, '2022-06-01', '2024-06-01', 'active', 'Department of Energy'),
('Quantum Computing', 6, '2023-03-10', '2026-03-10', 'active', 'Private Industry'),
('Advanced Materials', 7, '2021-09-01', '2024-09-01', 'active', 'Research Grant'),
('Data Privacy', 2, '2023-05-20', '2025-05-20', 'active', 'Tech Company'),
('Robotics Automation', 4, '2022-11-15', '2024-11-15', 'active', 'Manufacturing Consortium'),
('Climate Modeling', 5, '2023-02-01', '2026-02-01', 'active', 'Environmental Agency'),
('Business Analytics', 8, '2023-07-01', '2025-07-01', 'active', 'Corporate Sponsor');

INSERT INTO ProjectParticipants (project_id, participant_type, participant_id, role, joined_at) VALUES
(1, 'faculty', 1, 'Principal Investigator', '2023-01-15'),
(1, 'student', 1, 'Research Assistant', '2023-02-01'),
(1, 'student', 2, 'Research Assistant', '2023-02-01'),
(2, 'faculty', 3, 'Principal Investigator', '2022-06-01'),
(2, 'student', 4, 'Research Assistant', '2022-07-15'),
(3, 'faculty', 6, 'Principal Investigator', '2023-03-10'),
(3, 'student', 7, 'Research Assistant', '2023-04-01'),
(4, 'faculty', 7, 'Principal Investigator', '2021-09-01');

DESCRIBE Courses;

DROP VIEW IF EXISTS AcademicPerformanceSummary;
-- AcademicPerformanceSummary
CREATE VIEW AcademicPerformanceSummary AS
SELECT 
    c.course_id,
    c.code AS CourseCode,
    c.title AS CourseTitle,
    sem.name AS SemesterName,
    ROUND(AVG(e.grade_points), 2) AS Average_GPA,
    COUNT(e.student_id) AS Total_Students,
    d.name AS DepartmentName
FROM Enrollments e
JOIN Courses c ON e.course_id = c.course_id
JOIN Semesters sem ON e.semester_id = sem.semester_id
JOIN Departments d ON c.department_id = d.department_id
WHERE e.status = 'completed'
GROUP BY c.course_id, sem.semester_id, c.title, sem.name, d.name
ORDER BY d.name, sem.start_date, c.title;
-- EnrollmentTrendView
CREATE VIEW EnrollmentTrendView AS
SELECT 
    p.program_id,
    p.name AS ProgramName,
    sem.name AS SemesterName,
    COUNT(DISTINCT e.student_id) AS Enrolled_Students
FROM Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Programs p ON s.program_id = p.program_id
JOIN Semesters sem ON e.semester_id = sem.semester_id
GROUP BY p.program_id, sem.semester_id, sem.name
ORDER BY p.name, sem.start_date;

-- JOIN Operations with Multi-Table Joins
SELECT 
    f.first_name, 
    f.last_name, 
    f.academic_rank,
    d.name AS department_name,
    c.code AS course_code,
    c.title AS course_title,
    sem.name AS semester,
    ta.role
FROM Faculty f
JOIN Departments d ON f.department_id = d.department_id
JOIN TeachingAssignments ta ON f.faculty_id = ta.faculty_id
JOIN Courses c ON ta.course_id = c.course_id
JOIN Semesters sem ON ta.semester_id = sem.semester_id
WHERE sem.name = 'Fall 2023';

-- Aggregation with GROUP BY and HAVING
SELECT 
    p.name AS program_name,
    d.name AS department_name,
    COUNT(DISTINCT s.student_id) AS total_students,
    ROUND(AVG(e.grade_points), 2) AS avg_program_gpa,
    COUNT(CASE WHEN e.grade_points > 3.5 THEN 1 END) AS high_achievers
FROM Programs p
JOIN Students s ON p.program_id = s.program_id
JOIN Departments d ON p.department_id = d.department_id
JOIN Enrollments e ON s.student_id = e.student_id
WHERE e.status = 'completed'
GROUP BY p.program_id, p.name, d.name
HAVING avg_program_gpa > 3.0
   AND high_achievers >= 2
ORDER BY avg_program_gpa DESC;

-- Conditional Logic using CASE
SELECT 
    s.first_name,
    s.last_name,
    p.name AS program,
    ROUND(AVG(e.grade_points), 2) AS cumulative_gpa,
    CASE 
        WHEN AVG(e.grade_points) >= 3.7 THEN 'Excellent'
        WHEN AVG(e.grade_points) >= 3.3 THEN 'Very Good'
        WHEN AVG(e.grade_points) >= 2.7 THEN 'Good'
        WHEN AVG(e.grade_points) >= 2.0 THEN 'Satisfactory'
        ELSE 'At Risk'
    END AS performance_category,
    CASE 
        WHEN s.status = 'graduated' THEN 'Alumni'
        WHEN s.status = 'active' AND AVG(e.grade_points) >= 3.5 THEN 'Honors Candidate'
        ELSE 'Current Student'
    END AS student_status
FROM Students s
JOIN Programs p ON s.program_id = p.program_id
JOIN Enrollments e ON s.student_id = e.student_id
WHERE e.status = 'completed'
GROUP BY s.student_id, s.first_name, s.last_name, p.name, s.status
ORDER BY cumulative_gpa DESC;

-- Subqueries Correlated 
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    p.name AS program,
    ROUND(AVG(e.grade_points), 2) AS student_gpa,
    (SELECT ROUND(AVG(e2.grade_points), 2)
     FROM Enrollments e2
     JOIN Students s2 ON e2.student_id = s2.student_id
     WHERE s2.program_id = p.program_id 
       AND e2.status = 'completed') AS program_avg_gpa
FROM Students s
JOIN Programs p ON s.program_id = p.program_id
JOIN Enrollments e ON s.student_id = e.student_id
WHERE e.status = 'completed'
GROUP BY s.student_id, s.first_name, s.last_name, p.name, p.program_id
HAVING student_gpa > (SELECT ROUND(AVG(e2.grade_points), 2)
                      FROM Enrollments e2
                      JOIN Students s2 ON e2.student_id = s2.student_id
                      WHERE s2.program_id = p.program_id 
                        AND e2.status = 'completed')
ORDER BY (student_gpa - program_avg_gpa) DESC;

-- Subqueries non-Correlated 
SELECT 
    dept_name,
    course_code,
    course_title,
    enrollment_count,
    department_rank
FROM (
    SELECT 
        d.name AS dept_name,
        c.code AS course_code,
        c.title AS course_title,
        COUNT(e.enrollment_id) AS enrollment_count,
        RANK() OVER (PARTITION BY d.department_id ORDER BY COUNT(e.enrollment_id) DESC) AS department_rank
    FROM Courses c
    JOIN Departments d ON c.department_id = d.department_id
    JOIN Enrollments e ON c.course_id = e.course_id
    GROUP BY d.department_id, d.name, c.course_id, c.code, c.title
) AS ranked_courses
WHERE department_rank <= 3
ORDER BY dept_name, department_rank;
--
SELECT 
    student_name,
    program_name,
    cumulative_gpa,
    program_rank,
    department_rank
FROM (
    SELECT 
        CONCAT(s.first_name, ' ', s.last_name) AS student_name,
        p.name AS program_name,
        d.name AS department_name,
        ROUND(AVG(e.grade_points), 2) AS cumulative_gpa,
        RANK() OVER (PARTITION BY p.program_id ORDER BY AVG(e.grade_points) DESC) AS program_rank,
        RANK() OVER (PARTITION BY d.department_id ORDER BY AVG(e.grade_points) DESC) AS department_rank,
        COUNT(e.enrollment_id) AS courses_completed
    FROM Students s
    JOIN Programs p ON s.program_id = p.program_id
    JOIN Departments d ON p.department_id = d.department_id
    JOIN Enrollments e ON s.student_id = e.student_id
    WHERE e.status = 'completed'
    GROUP BY s.student_id, s.first_name, s.last_name, p.program_id, p.name, d.department_id, d.name
    HAVING courses_completed >= 2
) AS ranked_students
WHERE program_rank <= 5
ORDER BY department_name, program_rank;



-- Step 1: Add helpful indexes
CREATE INDEX idx_students_program ON Students(program_id);
CREATE INDEX idx_enrollments_student_status ON Enrollments(student_id, status);

-- Step 2: Rewritten optimized query
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    p.name AS program,
    ROUND(AVG(e.grade_points), 2) AS student_gpa,
    pa.program_avg_gpa,
    ROUND(AVG(e.grade_points) - pa.program_avg_gpa, 2) AS gpa_difference
FROM Students s
JOIN Programs p ON s.program_id = p.program_id
JOIN Enrollments e ON s.student_id = e.student_id
JOIN (
    SELECT 
        s2.program_id,
        ROUND(AVG(e2.grade_points), 2) AS program_avg_gpa
    FROM Enrollments e2
    JOIN Students s2 ON e2.student_id = s2.student_id
    WHERE e2.status = 'completed'
    GROUP BY s2.program_id
) AS pa ON pa.program_id = p.program_id
WHERE e.status = 'completed'
GROUP BY s.student_id, s.first_name, s.last_name, p.name, pa.program_avg_gpa
HAVING student_gpa > pa.program_avg_gpa
ORDER BY gpa_difference DESC;
