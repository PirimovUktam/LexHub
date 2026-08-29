-- ==============================================================================
-- MIGRATION: 20260821_community_qa_triggers.sql
-- LexHub Platform — Community Q&A Triggers & Security Enhancements
-- Dependencies: 20260819_base_schema.sql (questions, answers, votes)
-- ==============================================================================

-- 1. Automatic Answers Count Maintenance on Questions
CREATE OR REPLACE FUNCTION public.handle_answer_counter()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.questions
        SET answers_count = answers_count + 1,
            updated_at = now()
        WHERE id = NEW.question_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.questions
        SET answers_count = GREATEST(0, answers_count - 1),
            updated_at = now()
        WHERE id = OLD.question_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'answers') THEN
        DROP TRIGGER IF EXISTS trg_handle_answer_counter ON public.answers;
        CREATE TRIGGER trg_handle_answer_counter
        AFTER INSERT OR DELETE ON public.answers
        FOR EACH ROW EXECUTE FUNCTION public.handle_answer_counter();
    END IF;
END $$;

-- 2. Automatic Votes Count Maintenance on Questions and Answers
CREATE OR REPLACE FUNCTION public.handle_vote_counter()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.target_type = 'question' THEN
            UPDATE public.questions
            SET upvotes_count = upvotes_count + 1
            WHERE id = NEW.target_id;
        ELSIF NEW.target_type = 'answer' THEN
            UPDATE public.answers
            SET upvotes_count = upvotes_count + 1
            WHERE id = NEW.target_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.target_type = 'question' THEN
            UPDATE public.questions
            SET upvotes_count = GREATEST(0, upvotes_count - 1)
            WHERE id = OLD.target_id;
        ELSIF OLD.target_type = 'answer' THEN
            UPDATE public.answers
            SET upvotes_count = GREATEST(0, upvotes_count - 1)
            WHERE id = OLD.target_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'votes') THEN
        DROP TRIGGER IF EXISTS trg_handle_vote_counter ON public.votes;
        CREATE TRIGGER trg_handle_vote_counter
        AFTER INSERT OR DELETE ON public.votes
        FOR EACH ROW EXECUTE FUNCTION public.handle_vote_counter();
    END IF;
END $$;

-- 3. Answer Acceptance Trigger (Single Accepted Answer & Question Status Sync)
CREATE OR REPLACE FUNCTION public.handle_answer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
    v_question_owner UUID;
BEGIN
    IF (NEW.is_accepted IS DISTINCT FROM OLD.is_accepted) THEN
        -- Find question owner
        SELECT user_id INTO v_question_owner
        FROM public.questions
        WHERE id = NEW.question_id;

        -- Verify caller is Question Owner or Moderator/Admin
        IF (auth.uid() != v_question_owner AND NOT public.is_admin_or_moderator() AND current_user != 'service_role') THEN
            RAISE EXCEPTION 'Unauthorized: Only the question author can accept an answer.';
        END IF;

        -- If accepted, unaccept all other answers for this question and update status
        IF NEW.is_accepted = TRUE THEN
            UPDATE public.answers
            SET is_accepted = FALSE
            WHERE question_id = NEW.question_id AND id != NEW.id AND is_accepted = TRUE;

            UPDATE public.questions
            SET status = 'answered',
                updated_at = now()
            WHERE id = NEW.question_id;
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'answers') THEN
        DROP TRIGGER IF EXISTS trg_handle_answer_acceptance ON public.answers;
        CREATE TRIGGER trg_handle_answer_acceptance
        BEFORE UPDATE ON public.answers
        FOR EACH ROW EXECUTE FUNCTION public.handle_answer_acceptance();

        -- 4. Update Answers RLS Policy for Acceptance by Question Owner
        ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Answers are viewable by everyone" ON public.answers;
        CREATE POLICY "Answers are viewable by everyone" ON public.answers FOR SELECT USING (true);

        DROP POLICY IF EXISTS "Authenticated users can post answers" ON public.answers;
        CREATE POLICY "Authenticated users can post answers" ON public.answers 
        FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

        DROP POLICY IF EXISTS "Authors can update their answer" ON public.answers;
        DROP POLICY IF EXISTS "Authors or Question owners can update answer" ON public.answers;
        CREATE POLICY "Authors or Question owners can update answer" ON public.answers 
        FOR UPDATE USING (
            auth.uid() = user_id 
            OR EXISTS (
                SELECT 1 FROM public.questions 
                WHERE id = answers.question_id AND user_id = auth.uid()
            )
            OR public.is_admin_or_moderator()
        ) WITH CHECK (
            auth.uid() = user_id 
            OR EXISTS (
                SELECT 1 FROM public.questions 
                WHERE id = answers.question_id AND user_id = auth.uid()
            )
            OR public.is_admin_or_moderator()
        );
    END IF;
END $$;
