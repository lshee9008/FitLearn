# FitLearn Firebase Schema

## Core Collections

### `users/{userId}`
- `name`: string
- `email`: string
- `role`: `student | professor`
- `created_at`: timestamp
- `learning_profile`: map
  - `learning_style`
  - `vark`
  - `focus_pattern`
  - `difficulty_response`
  - `interaction`
  - `cognitive_style`
  - `confidence_score`

### `diagnosis/{userId}`
- `profile`: map
- `report`: map
- `diagnosed_at`: timestamp

### `rooms/{roomId}`
- `room_id`: string
- `room_code`: string
- `professor_uid`: string
- `professor_name`: string
- `subject`: string
- `description`: string
- `room_type`: `online | offline`
- `synopsis`: string
- `core_concepts`: string[]
- `youtube_url`: string
- `has_quiz`: bool
- `students`: string[]
- `created_at`: timestamp

### `rooms/{roomId}/lectures/{lectureId}`
- `lecture_id`: string
- `room_id`: string
- `title`: string
- `week_number`: number
- `original_text`: string
- `core_points`: array
- `confirmed`: bool
- `original_file_url`: string
- `original_filename`: string
- `created_at`: timestamp

### `rooms/{roomId}/lectures/{lectureId}/reforged/{userId}`
- `styles`: map
  - `시각형`
  - `청각형`
  - `읽기형`
  - `실습형`
  - `요약형`
  - `상세형`
- `primary_style`: string
- `subject_level`: `beginner | intermediate | advanced`
- `generated_at`: timestamp

### `rooms/{roomId}/notices/{noticeId}`
- `notice_id`: string
- `room_id`: string
- `title`: string
- `content`: string
- `professor_uid`: string
- `created_at`: timestamp

### `room_applications/{roomId}_{userId}`
- `application_id`: string
- `room_id`: string
- `user_id`: string
- `student_name`: string
- `professor_uid`: string
- `room_subject`: string
- `room_type`: `online | offline`
- `status`: `pending | approved | rejected`
- `note`: string
- `review_note`: string
- `created_at`: timestamp
- `updated_at`: timestamp

### `subject_levels/{userId}_{roomId}`
- `user_id`: string
- `room_id`: string
- `score`: number
- `subject_level`: `beginner | intermediate | advanced`
- `correct_count`: number
- `total_count`: number
- `submitted_at`: timestamp

## Recommended Next-Step Extensions

### `rooms/{roomId}/lectures/{lectureId}` additions for video
- `video_type`: `youtube | upload | none`
- `video_url`: string
- `video_title`: string
- `video_duration`: number
- `chapters`: array
- `summary_status`: `idle | processing | ready | failed`
- `summary_cache`: map
- `visual_assets`: array

## Performance Rules
- Prefer `users.learning_profile` for room roster summaries instead of rereading `diagnosis`.
- Cache list/read-heavy queries in Redis with short TTL.
- Invalidate cache on room create, join, meta update, lecture upload, quiz regeneration, and subject-level submission.
- Student portal should be driven by a single hub payload: `enrolled_rooms + discover_rooms + applications + active_room`.
- Keep room list and student home summary behind Riverpod providers on the frontend.
