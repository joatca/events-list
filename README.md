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

| Name   | Purpose                                                                                        |
|--------|------------------------------------------------------------------------------------------------|
| `css`  | a [Nokogiri](https://nokogiri.org/)-compatible CSS specifier to find the HTML element of group |
| `proc` | a Ruby lambda or `Proc` object that the found element is passed to to extract text             |

For each finder, if `css:` exists then the current HTML document is searched for that CSS. For `main` this is the entire document, for `events` is the the result from `main` and for everything else it is the subdocument for the current event. If `proc` exists then the found subdocument is passed to the subdocument and whatever it returns is the result. `proc` exists to do arbitrary processing and manging of the raw data from the website.

Note that the output of `css` is always a Nokogiri object so if you need plain text then the absolute minimal `proc` is `->(x) { x.text }`

For each source the code proceeds as follows:

1. find `main`
2. find and loop over each of the `events`
  1. if any `filters` exist and any of them return `true`, skip this event
  2. fetch `link` and `title`
  3. if only `date` is given, pass it to `Chronic` to parse into a timestamp; if both `date` and `time` are
     given then are joined with a space and passed to `Chronic`, otherwise if `datetime` is given pass the
     contents to `Chronic`. It is an error to have neither `date` nor `datetime` but `time` is optional.

