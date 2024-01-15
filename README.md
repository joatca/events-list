This code scrapes website calendars from multiple sites and generates a markdown summary intended for a Hugo site. Currently the configuration works with sites in London, Ontario, Canada but in principle can be adapted to any sites.

## Site Configuration

The import file is the driver file `event-list-config.rb`

Each source describes how to scrape a particular site. Apart from descriptive information it contains several possible `finders`:

| Name       | Purpose                                                                   |
|------------|---------------------------------------------------------------------------|
| `main`     | the section of the site containing a list of events                       |
| `events`   | how to find each event within `main`                                      |
| `link`     | within each event, how to find a web link to the event                    |
| `title`    | within each event, how to find the text title                             |
| `date`     | within each event, how to find the date of the event                      |
| `time`     | within each event, how to find the time of the event                      |
| `datetime` | Alternative to `date` and `time` if the date and time are found together  |
| `filters`  | within each event, an element that may cause the event to be filtered out |

Each finder has at least one of:

| Name   | Purpose                                                                                                                                        |
|--------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `css`  | a [Nokogiri](https://nokogiri.org/)-compatible CSS specifier to find the HTML element of group                                                 |
| `proc` | a Ruby lambda or `Proc` object that the found element is passed to to extract text                                                             |
| `if`   | only for filters, a Ruby lambda or `Proc` object that should return a truthy value if the event should be skipped and otherwise a falsey value |

For each finder, if `css:` exists then the current HTML document is searched for that CSS. For `main` this is the entire document, for `events` is the the result from `main` and for everything else it is the subdocument for the current event. If `proc` exists then the found subdocument is passed to the subdocument and whatever it returns is the result. `proc` exists to do arbitrary processing and manging of the raw data from the website.

Note that the output of `css` is always a Nokogiri object so if you need plain text then the absolute minimal `proc` is `->(x) { x.text }`

For each source the code proceeds as follows:

- find `main`
  - within `main` find and loop over each of the `events`
    - if any `filters` exist and any of them return `true`, skip this event
    - fetch `link` and `title`
    - if only `date` is given, pass it to [Chronic](https://github.com/mojombo/chronic)'s `Chronic.parse` to
      parse into a timestamp; if both `date` and `time` are given then are joined with a space and passed to
      `Chronic.parse`, otherwise if `datetime` is given pass the contents to `Chronic.parse`. It is an error to
      have neither `date` nor `datetime` but `time` is optional.

For example consider the finders for Museum London:

      finders: {
        main: {
          css: "div.event"
        },
        events: {
          css: "div.col-xs-9"
        },
        link: {
          css: "a.num",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "a.num h3",
          proc: ->(x) { x.text }
        },
        datetime: {
          css: "span.event-date",
          proc: ->(x) { x.text.gsub(/^\S+ "/, '') }
        }
      }
      
The code fetches `div.event` then loops through each `div.col-xs-9` within that. For each one the event link is extracted by finding `a.num` then calling `.attribute("href").value` on it, the event title by finding `a.num h3` then calling `.text`, and the date and time together by finding `span.event-date` then calling `.text.gsub(/^\S+ "/, '')` to strip off the leading word and a quote (`Chronic.parse` doesn't support day names), then passing the resulting text to `Chronic.parse`.
