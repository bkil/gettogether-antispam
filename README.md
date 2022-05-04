# GetTogether.community spam prevention ideas

## Source database schema

TODO: Certain fields may not be visible to the crawler, because they need authentication with a higher permission level roles and/or have became fully private recently.

### General

* Categories.csv(id, name): enum none (--), Music&Dancing, Food&Dining, Community&Activism, Outdoor&Adventure, Computers&Technology, Gaming, 
* Media.csv(id=url, filename, file_size, mime, width, height, average color, hash, maybe_create_time)
* media/$id.data
* Cities.csv(id, name, country_id, lat, lon, zoom)
* Countries.csv(id, name)

### Users

* Users.csv(id, name, website, timezone, media_id, maybe_join_time, is_deleted)
* UserCategories.csv(id, user_id, category_id)
* EventParticipant.csv(id, event_id, user_id, participation_id, is_host, maybe_create_time, maybe_update_time)
* Participation(id, name) enum: Yes, No, Maybe

### Talks

* Talks.csv(id, speaker_id, title, talk_type_id, website, category_id)
* talks/$id.html: abstract
* TalkType.csv(id, name): enum Presentation, Workshop, Panel, Roundtable, Q&A, Demonstration
* Speakers.csv(id, user_id, media_id, title)
* SpeakerCategories.csv(id, speaker_id, category_id)
* speaker/$id.txt: biography
* TalkInstance.csv(id, event_id, talk_id)

### Teams

* Teams.csv(id, slug, name, category_id, city_id, website, timezone, media_id, is_deleted)
* TeamMember.csv(id, team_id, user_id, role_id, maybe_join_time)
* Roles.csv(id, name): enum none, Moderator, Administrator
* teams-description/$id.html: description
* teams-about/$id.html: about

### Events

* Events.csv(id, slug, team_id, user_id, name, start_time, end_time, maybe_event_series_id, website, announce_url, attendee_limit, have_comments, have_photos, have_talks, have_sponsors, place_id, is_deleted)
* events/$id.html: summary
* EventPhoto.csv(id, event_id, photo_id)
* Photo.csv(id, thumb_media_id, full_media_id, title)
* photo/$id.html: caption
* Places.csv(id, name, address, city_id, website, google_maps_url)
* EventSeries.csv(id, slug, team_id, user_id, name, start_time, end_time, repetition, attendee_limit, place_id)
* event-series/$id.html: summary
* Comment.csv(id, event_id, user_id, create_time, update_time, text)
* EventUpdates.csv(id, event_id, maybe_update_time)
* Sponsors.csv(id, name, website, media_id)
* SponseredEvents.csv(id, sponsor_id, event_id)

## Heuristics

### Preloading

* crawl the whole website
* building reputation of users based on past events, teams
* ephemeral database: preprocessed from this, update it incrementally later

### Reputation propagation

* Iterative closure of the relation of guilt or innocence
* Increment a reputation counter for each separately
* Don't propagate further from a node that has reputation for both definite guilt and definite innocence, need to review these manually
* TODO: Perhaps introduce four counters: definitely/potentially guilty/innocent, and consider summarily guilty/innocent based on rules

### Content

Long form description, title, link, place, media or combination thereof taken together.

* Be advised that guilty actors may also copy innocent content to dilute their signature
* Mark all links, media and places of definitely innocent entities as definitely innocent
* If a given guilty user page only contains a single link, mark it as potentially guilty
* If a given guilty team page or event page only contains a single link, mark it as definitely guilty
* Mark content containing certain keywords (+DNSBL) from a manually curated list as definitely guilty
* Mark a given user-, team- or event page definitely guilty if it contains definitely guilty content
* If unmarked content is unique within the system to guilty entities, mark it as maybe guilty, mark all future referring entities as maybe guilty

### Team reputation

* Innocent if any innocent event created
* Innocent if only innocent members joined and it still has an admin
* Maybe guilty if no admin joined
* Maybe guilty if only 1 member joined
* Maybe guilty if it has no events
* Maybe guilty if it has events more than 4 times within the next or previous 28 days
* Maybe guilty if it has events more than 2 times within the next or previous 7 days
* Maybe guilty if it never had an event with a place
* Guilty if guilty member joined
* Guilty if contains any guilty moderator or admin

### Event reputation

* Innocent if event was created by innocent team
* Innocent if event is attended by innocent user
* Maybe innocent if event is attended by at least 3 users
* Maybe innocent if it has talks
* Maybe guilty if duplicate by title, description, URL and place with another event by same team
* Maybe guilty if event is attended by only 1 user
* Maybe guilty if longer than 4 hours
* Maybe guilty if start time not at least 1 day in the future
* Maybe guilty if starts at an odd hour (e.g., midnight, noon)
* Guilty if commented by guilty user
* Guilty if guilty user attends
* Guilty if longer than 1 week
* Guilty if created by guilty team
* Guilty if it overlaps in time with another event by same team with matching title and description but different place or website

### User reputation

* Innocent if joined an innocent team
* Innocent if joined multiple teams
* Innocent if participated events of multiple teams
* Innocent if commented events of multiple teams
* Maybe guilty if created new team and new event within 1 day of registration

## Polling

### Daily

* Invoke list all events endpoint
* TODO: Endpoint for list all teams fails with HTTP 500

### Often

For example, once every 15 minutes.

* Speculatively probe new users
* Speculatively probe new teams
* Speculatively probe new events (optional)
* Piecewise update event pages that have not yet ended (for RSVP changes and new comments)
* Piecewise update team pages based on how recently their last event ended (for joined members)

### On demand

When a new event occurs from a team that is not definitely innocent:

* Cache pages for some time (e.g., 1-24 hours, less in spam wave mode)
* Get event page
* Update team page
* Update profile page of each user who RSVP'd to event or joined team
* Recompute reputations, if changed for any entity, update pages of all entities linked to that one and repeat

### Piecewise update

* Only fetch a single page per execution
* Order by probability of expecting a new change
* Rank lower if the entity is definitely innocent
* Rank higher if the end time of an event is closer to the present
* Rank user higher if the user recently commented an event, RSVP'd to an event or joined a team
* Rank higher if a change was detected recently
* Rank higher if it was fetched a long time ago
* Fetch an entity at least once a year

### Speculative ID probing

* Probability of interval exponentially decreasing with distance, for example based on the position of the lowest set bit within a binary counter.
* Reset after each success.

## Ephemeral database schema

### Estimate

Estimate various properties that are not presented on the public website based on differential monitoring.

* when did a user register, join a team, RSVP on an event
* when did a team get created
* reputation of teams, events, users and assets

### Overrides

* entity or asset reputation

### Index

* all IDs that ever existed for teams, events and users, especially maximum value
* events ordered by the distance between its end time and the present
* events that have not ended yet
* teams ordered by how recent their most recent event ended
* incidence of given links and domains present in any field or blob
* temporal coverage of a given non-innocent asset overall and per team (in what percentage of real time does it occur including series)
* whether a given entity has already been reported in the past or not

## Action

* report new guilty entities
* send out in daily digest email (e.g., cron echo)
* generate RSS of entities to review as soon as possible
* generate RSS of reviewed entities found to be definitely guilty in batches
* option to trust and follow other instances of this bot: mirror results (follow RSS) and ensure that polling is load balanced with failover
* send in via a Matrix bot immediately to a review room
* verify each hint in the review room manually, add review result to overrides, delete false alarms
* collect and forward links to reviewed results daily or weekly to upstream project owner: perhaps include a few words of preview if it contains no sensitive keywords
