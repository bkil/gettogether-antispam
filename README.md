# GetTogether.community spam prevention ideas

## Polling new entries

* Probability exponentially decreasing with distance, for example based on the position of the lowest set bit within a counter.
* Reset after each success.

## Full database schema

* Categories.csv(id, name): enum none (--), Music&Dancing, Food&Dining, Community&Activism, Outdoor&Adventure, Computers&Technology, Gaming, 
* Media.csv(id, filename, hash)
  * media/$id.data
* Users.csv(id, name, website, timezone, media_id, maybe_join_time)
  * UserCategories.csv(id, user_id, category_id)
* Teams.csv(id, slug, name, category_id, city_id, website, timezone, media_id)
  * TeamMember.csv(id, team_id, user_id, role_id, maybe_join_time)
* Cities.csv(id, name, country_id, lat, lon, zoom)
  * Countries.csv(id, name)
* Roles.csv(id, name): enum none, Moderator, Administrator
  * teams-description/$id.html: description
  * teams-about/$id.html: about
* Events.csv(id, team_id, user_id, name, start_time, end_time, maybe_event_series_id, website, announce_url, attendee_limit, have_comments, have_photos, have_talks, have_sponsors, place_id)
  * events/$id.html: summary
  * EventUpdates.csv(id, event_id, maybe_update_time)
  * EventPhoto.csv(id, event_id, photo_id)
  * Photo.csv(id, media_id, title)
    * photo/$id.html: caption
  * TalkInstance.csv(id, event_id, talk_id)
* EventSeries.csv(id, team_id, user_id, name, start_time, end_time, repetition, attendee_limit, place_id)
  * event-series/$id.html: summary
* Places.csv(id, name, address, city, website, google_maps_url)
* EventParticipant.csv(id, event_id, user_id, participation_id, maybe_create_time, maybe_update_time)
  * Participation(id, name) enum: Yes, No, Maybe
* Comment.csv(id, event_id, user_id, create_time, update_time, text)
* Talks.csv(id, speaker_id, title, talk_type_id, website, category_id)
  * talks/$id.html: abstract
  * TalkType.csv(id, name): enum Presentation, Workshop, Panel, Roundtable, Q&A, Demonstration
  * Speakers.csv(id, user_id, media_id, title)
  * SpeakerCategories.csv(id, speaker_id, category_id)
  * speaker/$id.txt: biography
