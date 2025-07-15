

 CREATE TABLE foursquare (
      fsq_place_id        text,
      name                text,
      latitude            text,
      longitude           text,
      address             text,
      locality            text,
      region              text,
      postcode            text,
      admin_region        text,
      post_town           text,
      po_box              text,
      country             text,
      date_created        text,
      date_refreshed      text,
      date_closed         text,
      tel                 text,
      website             text,
      email               text,
      facebook_id         text,
      instagram           text,
      twitter             text,
      fsq_category_ids    text,
      fsq_category_labels text,
      placemaker_url      text,
      bbox                text
);

\copy foursquare  FROM 'data/raw_data.csv'  WITH (    
      FORMAT csv,
      HEADER,
      DELIMITER ',',
      QUOTE '"',
      ESCAPE '"',
      NULL ''  
);

