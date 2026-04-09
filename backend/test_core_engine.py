import asyncio
import os
import sys

# 현재 디렉토리를 경로에 추가하여 services 모듈 임포트 가능하게 함
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.lecture_pipeline import LecturePipeline
from services.reforge_service import ReforgeService

async def main():
    print("=" * 60)
    print(" FitLearn Core Engine Test : 교안 재해석 시스템 테스트")
    print("=" * 60)
    
    print("\n[1] 학생 성향(프로파일) 직접 선택")
    print("-" * 50)
    
    # 기본 입력 처리
    def get_input(prompt_text, default):
        val = input(f"{prompt_text} [기본: {default}]: ").strip()
        return val if val else default

    learning_style = get_input(" - (1/5) VARK 학습 유형 (예: 시각형/청각형/읽기형/실습형)", "시각형")
    cognitive_style = get_input(" - (2/5) 인지 스타일 (예: 능동형/숙고형/직관형)", "숙고형")
    focus_pattern = get_input(" - (3/5) 집중 패턴 (예: 짧은 집중/긴 집중/시각적 자극에 반응)", "짧은 집중")
    pace = get_input(" - (4/5) 학습 페이스 (예: 빠른/중간/느린)", "빠른")
    kolb_type = get_input(" - (5/5) Kolb 학습자 유형 (예: 동화형/수렴형/확산형/조절형)", "동화형")

    profile = {
        "learning_style": learning_style,
        "cognitive_style": cognitive_style,
        "focus_pattern": focus_pattern,
        "pace": pace,
        "preferred_format": "마크다운/요약본",
        "kolb_type": kolb_type,
        "confidence_score": 85
    }

    print("\n[2] 테스트용 원본 교안 입력")
    print("-" * 50)
    print("원하시는 교안 텍스트를 입력하세요. (입력을 끝내려면 빈 줄에서 엔터를 두 번, 혹은 '끝' 입력 후 엔터)")
    
    lines = []
    while True:
        try:
            line = input()
            if line.strip() == "끝":
                break
            if not line:
                if lines and lines[-1] == "":
                    break
            lines.append(line)
        except EOFError:
            break
            
    original_content = "\n".join(lines).strip()
    
    if not original_content:
        # 기본 샘플 교안
        original_content = """데이터베이스 트랜잭션의 ACID 특성:
1. 원자성(Atomicity): 트랜잭션 내의 모든 작업이 모두 완료되거나 모두 취소되어야 합니다.
2. 일관성(Consistency): 트랜잭션 전후로 데이터베이스의 일관성 제약 조건이 항상 유지되어야 합니다.
3. 격리성(Isolation): 동시에 실행되는 여러 트랜잭션이 서로 간섭하지 않아야 합니다.
4. 지속성(Durability): 성공적으로 완료된 트랜잭션의 결과는 영구적으로 반영되어야 합니다.

트랜잭션을 구현하기 위해 DBMS는 락킹(Locking) 기법이나 MVCC(다중 버전 동시성 제어) 기법을 사용하여 동시성을 관리하고 로깅 시스템을 통해 데이터 복구를 지원합니다."""
        print(f"\n[안내] 입력된 내용이 없어 기본 IT 공학 샘플 교안이 사용됩니다:\n{original_content}\n")

    print("\n" + "=" * 60)
    print("🤖 [Step 1] AI 파이프라인 가동: 핵심 내용 분석 (LecturePipeline)")
    print("=" * 60)
    
    pipeline = LecturePipeline()
    extracted = await pipeline.run(original_content)
    core_points = extracted.get("core_points", [])
    
    print(f"\n✅ 추출된 요약본: {extracted.get('lecture_summary', '')}")
    print(f"✅ 교안 난이도 측정 수준: {extracted.get('estimated_difficulty', '알 수 없음')}")
    print(f"✅ 추출된 핵심 포인트 ({len(core_points)}개):")
    for cp in core_points:
        print(f"    - [중요도 {cp.get('priority',3)}] {cp.get('content')}")

    print("\n" + "=" * 60)
    print("🤖 [Step 2] 학생 성향 맞춤 교안 재해석 시작 (ReforgeService)")
    print("    - 6가지 학습자 특화 스타일로 동시 변환 진행 중 ...")
    print("=" * 60)
    
    reforge_service = ReforgeService()
    # 6스타일로 전부 변환하던 부분을 선택된 단일 맞춤형 프로파일 적용으로 변경
    result = await reforge_service.reforge_for_student(original_content, core_points, profile)

    print(f"\n🎉 변환 완료! 아래에서 [{profile['learning_style']}] 맞춤형 교안을 확인하세요.\n")
    print("🌟🌟🌟 맞춤형 교안 결과 🌟🌟🌟")
    print(result)
    print("\n" + "-" * 70 + "\n")

    print("테스트 종료.")

if __name__ == "__main__":
    if "GEMINI_API_KEY" not in os.environ:
        # dotenv 로드 시도
        try:
            from dotenv import load_dotenv
            env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env.development")
            load_dotenv(env_path)
            print(f"[알림] {env_path} 에서 환경변수를 불러왔습니다.")
        except Exception:
            pass
            
        if "GEMINI_API_KEY" not in os.environ:
            print("❌ [오류] GEMINI_API_KEY 환경변수가 설정되지 않았습니다. .env.development 파일을 확인하세요.")
            sys.exit(1)
            
    asyncio.run(main())
