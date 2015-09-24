DELETE FROM wply_posts
	WHERE id > 13;

DELETE FROM wply_postmeta
	WHERE post_id > 13;

DELETE FROM wply_term_relationships
	WHERE object_id > 13;

DELETE FROM wply_terms
	WHERE term_id > 13;

DELETE FROM wply_term_taxonomy
	WHERE term_id > 13;


INSERT INTO wply_posts (
	sermon_id,
	post_author,
	post_title,
	post_name,
	post_type,
	post_date,
	post_date_gmt,
	post_modified_gmt,
	post_modified,
	comment_status,
	ping_status,
	post_status
)
SELECT
	sermon.id,
	1,
	sermon.title,
	sermon.alias,
	'wpfc_sermon',
	sermon.created,
	sermon.created,
	sermon.modified,
	sermon.modified,
	'closed',
	'closed',
	'publish'
FROM lrx9q_sermon_sermons sermon
	LEFT JOIN lrx9q_sermon_speakers speaker
		ON sermon.speaker_id = speaker.id
	LEFT JOIN lrx9q_sermon_series series
		ON sermon.series_id = series.id;
-- WHERE sermon.id > 10630;

INSERT INTO wply_postmeta (
	post_id,
	meta_key,
	meta_value
)
SELECT
	post.id,
	'sermon_date',
	UNIX_TIMESTAMP(sermon.sermon_date)
FROM lrx9q_sermon_sermons sermon
	INNER JOIN wply_posts post
		ON post.sermon_id = sermon.id;

INSERT INTO wply_postmeta (
	post_id,
	meta_key,
	meta_value
)
SELECT
	post.id,
	'sermon_description',
	sermon.notes
FROM lrx9q_sermon_sermons sermon
	INNER JOIN wply_posts post
		ON post.sermon_id = sermon.id;

INSERT INTO wply_postmeta (
	post_id,
	meta_key,
	meta_value
)
SELECT
	post.id,
	'sermon_audio',
	sermon.audiofile
FROM lrx9q_sermon_sermons sermon
	INNER JOIN wply_posts post
		ON post.sermon_id = sermon.id;

--


INSERT INTO wply_postmeta (
	post_id,
	meta_key,
	meta_value
)
SELECT
	post.id,
	'bible_passage',
	GREATEST(
		scripture.text,
		SUBSTRING_INDEX(SUBSTRING_INDEX(sermon.notes, '|', 2), '|', -1)
		-- also we need to parse scripture.book, .cap1, .vers1, .cap2, .vers2
	)
FROM lrx9q_sermon_sermons sermon
	INNER JOIN wply_posts post
		ON post.sermon_id = sermon.id
	LEFT JOIN lrx9q_sermon_scriptures scripture
		ON scripture.sermon_id = sermon.id;

INSERT INTO wply_postmeta (
	post_id,
	meta_key,
	meta_value
)
SELECT
	post.id,
	'wpfc_service_type_select',
	CASE
	WHEN sermon.title RLIKE '6 ?[pP][mM]' THEN
		'a:1:{i:0;s:1:"9";}'
	ELSE
		'a:1:{i:0;s:1:"8";}'
	END
FROM lrx9q_sermon_sermons sermon
	INNER JOIN wply_posts post
		ON post.sermon_id = sermon.id;
-- must add term_relationships to this -- maybe even instead of this?

INSERT INTO wply_term_relationships (object_id, term_taxonomy_id)
	SELECT
		post.id,
		CASE
		WHEN sermon.title RLIKE '6 ?[pP][mM]' THEN
			9
		ELSE
			8
		END
	FROM lrx9q_sermon_sermons sermon
		INNER JOIN wply_posts post
			ON post.sermon_id = sermon.id;

-- speakers --> preachers

-- FIXME: speaker.alias and series.alias is sometimes blank and wply_terms mustn't be

SELECT MAX(term_id) INTO @max_wply_term_id_before_insert FROM wply_terms;
INSERT INTO wply_terms (name, slug)
	SELECT speaker.title, COALESCE(speaker.alias)
	FROM lrx9q_sermon_speakers speaker
	GROUP BY speaker.title;
INSERT INTO wply_term_taxonomy (term_id, taxonomy)
	SELECT term_id, 'wpfc_preacher'
	FROM wply_terms
	WHERE term_id > @max_wply_term_id_before_insert;

INSERT INTO wply_term_relationships (object_id, term_taxonomy_id)
	SELECT DISTINCT post.id, tt.term_taxonomy_id
	FROM lrx9q_sermon_sermons sermon
		INNER JOIN wply_posts post
			ON post.sermon_id = sermon.id
		LEFT JOIN lrx9q_sermon_speakers speaker
			ON sermon.speaker_id = speaker.id
		LEFT JOIN wply_terms term
			ON speaker.title = term.name
		LEFT JOIN wply_term_taxonomy tt
			ON tt.term_id = term.term_id
		WHERE tt.taxonomy = 'wpfc_preacher';

-- series

SELECT MAX(term_id) INTO @max_wply_term_id_before_insert FROM wply_terms;
INSERT INTO wply_terms (name, slug)
	SELECT series.title, COALESCE(series.alias)
	FROM lrx9q_sermon_series series
	GROUP BY series.title;
INSERT INTO wply_term_taxonomy (term_id, taxonomy)
	SELECT term_id, 'wpfc_sermon_series'
	FROM wply_terms
	WHERE term_id > @max_wply_term_id_before_insert;

INSERT INTO wply_term_relationships (object_id, term_taxonomy_id)
	SELECT DISTINCT post.id, tt.term_taxonomy_id
	FROM lrx9q_sermon_sermons sermon
		INNER JOIN wply_posts post
			ON post.sermon_id = sermon.id
		LEFT JOIN lrx9q_sermon_series series
			ON sermon.series_id = series.id
		LEFT JOIN wply_terms term
			ON series.title = term.name
		LEFT JOIN wply_term_taxonomy tt
			ON tt.term_id = term.term_id
		WHERE tt.taxonomy = 'wpfc_sermon_series';





-- service, text, speaker, series
SELECT
	sermon.title,
	sermon.created,
	speaker.title speaker,
	series.title series,
	GREATEST(
		scripture.text,
		SUBSTRING_INDEX(SUBSTRING_INDEX(sermon.notes, '|', 2), '|', -1)
		-- also we need to parse scripture.book, .cap1, .vers1, .cap2, .vers2
	) bible_passage,
FROM lrx9q_sermon_sermons sermon
	LEFT JOIN lrx9q_sermon_speakers speaker
		ON sermon.speaker_id = speaker.id
	LEFT JOIN lrx9q_sermon_series series
		ON sermon.series_id = series.id
	LEFT JOIN lrx9q_sermon_scriptures scripture
		ON scripture.sermon_id = sermon.id
ORDER BY sermon.id DESC;


-- TODO: create sermon series, preachers, etc. so they appear in the lists 
