module DataFixup::FixOutOfSyncOutcomeAlignments
  def self.run
    # Active alignments to deleted rubrics
    ContentTag.joins("
      INNER JOIN rubrics r
        ON content_tags.content_id = r.id
        AND content_tags.content_type = 'Rubric'
    ").where("
      content_tags.tag_type = 'learning_outcome'
      AND content_tags.workflow_state = 'active'
      AND r.workflow_state = 'deleted'
    ").find_each do |ct|
      ct.destroy
    end

    # Active alignments to rubrics that should no longer be aligned
    ContentTag.joins("
      INNER JOIN rubrics r
        ON content_tags.content_id = r.id
        AND content_tags.content_type = 'Rubric'
    ").where("
      content_tags.tag_type = 'learning_outcome'
      AND content_tags.workflow_state = 'active'
      AND r.workflow_state = 'active'
      AND NOT r.data LIKE '%:learning_outcome_id: ' || content_tags.learning_outcome_id || '%'
    ").find_each do |ct|
      ct.destroy
    end

    # Active alignments to assignments without rubrics
    ContentTag.joins("
      INNER JOIN assignments a
        ON content_tags.content_id = a.id
        AND content_tags.content_type = 'Assignment'
      LEFT OUTER JOIN rubric_associations ra
        ON ra.association_id = a.id
        AND ra.association_type = 'Assignment'
    ").where("
      content_tags.tag_type = 'learning_outcome'
      AND content_tags.workflow_state = 'active'
      AND ra.id IS NULL
    ").find_each do |ct|
      ct.destroy
    end

    # Active alignments to assignments with rubrics
    # that don't have a matching alignment
    ContentTag.joins("
      INNER JOIN assignments a
        ON content_tags.content_id = a.id
        AND content_tags.content_type = 'Assignment'
      INNER JOIN rubric_associations ra
        ON ra.association_id = a.id
        AND ra.association_type = 'Assignment'
      INNER JOIN rubrics r
        ON ra.rubric_id = r.id
      LEFT OUTER JOIN content_tags ct2
        ON ct2.content_id = r.id
        AND ct2.content_type = 'Rubric'
        AND ct2.tag_type = 'learning_outcome'
        AND ct2.workflow_state = 'active'
        AND ct2.learning_outcome_id = content_tags.learning_outcome_id
    ").where("
      content_tags.tag_type = 'learning_outcome'
      AND content_tags.workflow_state = 'active'
      AND ct2.id IS NULL
    ").find_each do |ct|
      ct.destroy
    end
  end
end