{
  sources: [
    {
      name: "Covent Garden Market",
      abbrev: "CGM",
      pages: ["downtown", "adult"],
      url: "https://coventmarket.com/events/",
      debug_url: "cgm.html",
      finders: {
        main: {
          css: "section.tile-callout-cards"
        },
        events: {
          css: "div.grid-item a"
        },
        link: {
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "h3.event-title",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.event-date-time strong",
          proc: ->(x) { x.text.gsub(/-.*$/, '') }
        },
        time: {
          css: "div.event-date-time div",
          proc: ->(x) { x.text.gsub(/-.*$/, '') }
        }
      }
    },
    {
      name: "Aeolian Hall",
      abbrev: "Aeol",
      pages: ["downtown", "entertainment", "adult"],
      url: "https://aeolianhall.ca/events/",
      debug_url: "ah.html",
      finders: {
        main: {
          css: "section.events-feed"
        },
        events: {
          css: "div.event-tile"
        },
        link: {
          css: "a.link-wrap",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.event-title",
          proc: ->(x) { x.text.gsub(/^\s+(.*)\s+$/, '\1') }
        },
        date: {
          css: "span.event-date",
          proc: ->(x) { x.text.gsub(/^\S+ /, '') }
        },
        time: {
          css: "span.event-time",
          proc: ->(x) { x.text }
        }
      }
    },
    {
      name: "Museum London",
      abbrev: "Museum",
      pages: ["downtown", "entertainment", "culture", "adult"],
      url: "https://museumlondon.ca/programs-events",
      page_suffix: "/p",
      first_page: 1,
      max_page: 5,
      debug_url: "ml.html",
      debug_page_suffix: "_p",
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
    },
    {
      name: "London Music Hall",
      abbrev: "LMH",
      pages: ["downtown", "entertainment", "adult"],
      url: "http://londonmusichall.com/upcoming-events/",
      debug_url: "lmh.html",
      finders: {
        main: {
          css: "div.events"
        },
        events: {
          css: "div.event"
        },
        link: {
          css: "div.event-info h2 a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.event-info h2 a",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.event-info div.date",
          proc: ->(x) { x.text }
        },
        time: {
          css: "div.event-info div.times",
          proc: ->(x) { x.text.gsub("Doors:", '').gsub(/\/\s*Show:.*$/, '') }
        }
      }
    },
    {
      name: "Budweiser Gardens",
      abbrev: "BudG",
      pages: ["downtown", "entertainment", "adult"],
      url: "https://www.budweisergardens.com/events",
      debug_url: "bg.html",
      finders: {
        main: {
          css: "div.m-eventList"
        },
        events: {
          css: "div.m-eventItem"
        },
        link: {
          css: "h3.m-eventItem__title a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "h3.m-eventItem__title a",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.m-eventItem__date",
          proc: ->(x) { x.text.gsub(/\S+\s*$/, '') }
        }
      }
    },
    {
      name: "Don Wright Faculty of Music",
      abbrev: "FMus",
      pages: ["entertainment", "adult"],
      url: "http://www.events.westernu.ca/events/music/",
      debug_url: "dwfm.html",
      finders: {
        main: {
          css: "div#mainCol"
        },
        date_containers: {
          css: "div.day"
        },
        date: {
          css: "h2",
          proc: ->(x) { x.text.gsub(/^\S+\s+/, '') }
        },
        events: {
          css: "div.detailColFull"
        },
        link: {
          css: "div.detailColRight a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.detailColRight a",
          proc: ->(x) { x.text }
        },
        time: {
          css: "div.detailColLeft",
          proc: ->(x) { x.text }
        }
      }
    },
    {
      name: "Grand Theatre",
      abbrev: "Grand",
      pages: ["downtown", "entertainment", "adult"],
      url: "https://www.grandtheatre.com/events",
      debug_url: "grand.html",
      finders: {
        main: {
          css: "div.shows"
        },
        events: {
          css: "article"
        },
        link: {
          css: "a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.cont span",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.field-date",
          proc: ->(x) { x.text }
        }
      }
    },
    {
      name: "London Children's Museum",
      abbrev: "CMus",
      pages: ["downtown", "kids"],
      url: "https://www.londonchildrensmuseum.ca/events",
      page_suffix: "?page=",
      first_page: 0,
      max_page: 10,
      debug_url: "lcm.html",
      debug_page_suffix: "?page=",
      finders: {
        main: {
          css: "div.views-view-grid"
        },
        events: {
          css: "div.views-col"
        },
        link: {
          css: "div.views-field-title a",
          proc: ->(x) { x.attribute("href").value.delete("\n") }
        },
        title: {
          css: "div.views-field-title a",
          proc: ->(x) { x.text.delete("\n") }
        },
        datetime: {
          css: "div.views-field-field-date",
          proc: ->(x) { x.text.delete("\n") }
        },
        filters: [
          {
            css: "div.views-field-title a",
            if: ->(x) { x.text =~ /CLOSED/ }
          }
        ]
      }
    },
    {
      name: "Information London",
      abbrev: "Info",
      pages: ["downtown", "community", "adult"],
      url: "https://www.informationlondon.ca/Event/List",
      debug_url: "il.html",
      finders: {
        main: {
          css: "table.tablesorter tbody"
        },
        events: {
          css: "a.event-div"
        },
        link: {
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.event-info li.event-title",
          proc: ->(x) { x.text.gsub(/^\s+/, '') }
        },
        date: {
          css: "div.date-of-event",
          proc: ->(x) { x.text.delete("\r").delete("\n").gsub(/\s*\S+\s*$/, '') }
        },
        time: {
          css: "ul.event-details",
          proc: ->(x) { x.text.delete("\n").gsub(/ - .*/, '') }
        }
      }
    },
    {
      name: "Tourism London",
      abbrev: "Tour",
      pages: ["adult"],
      url: "https://www.londontourism.ca/events/all-events",
      page_suffix: "/page/",
      max_page: 30,
      debug_url: "tour.html",
      debug_page_suffix: "_page_",
      finders: {
        main: {
          css: "ul.eventCarousel"
        },
        events: {
          css: "li.before-slide a"
        },
        link: {
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.description h3",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.description time",
          proc: ->(x) {
            x.text.
              gsub(/^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+/, '').
              gsub(/(\w+)\s+(\d+)\s+-\s+(\d+)/, '\1 \2 - \1 \3')
          }
        },
        filters: [
          {
            css: "div.description p.location",
            if: ->(x) {
              [ /London Children's Museum/, /London Knights/, /London Music Hall/, /Rum Runners/, /Eldon House/,
                /Aeolian Hall/, /Covent Garden Market/, /Don Wright Faculty/, /Museum London/, /Museum London/,
                /Port Stanley Festival Theatre/, /RBC Place London/ ].any? { |e| x.text =~ e }
            }
          }
        ]
      }
    },
    {
      name: "Eldon House",
      abbrev: "Eldon",
      pages: ["community", "downtown", "adult"],
      url: "https://eldonhouse.ca/events/",
      debug_url: "eldon.html",
      finders: {
        main: {
          css: "div.elementor-posts-container"
        },
        events: {
          css: "div.elementor-element-58e298a"
        },
        link: {
          css: "div.elementor-button-wrapper a.elementor-button",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "div.elementor-element-ad95776 h3.elementor-heading-title",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.elementor-element-c029367",
          proc: ->(x) {
            x.text.
              gsub(/^[\r\n\t]+/, '').
              gsub(/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+/, '').
              gsub(/[\r\n\t].*$/, '').
              gsub(/,\s*\d{1,2}:.*$/, '').
              gsub(/,\s*Drop in.*/, '')
          }
        },
        rangesep: /\s*(?:to|and) \s*/
      }
    },
    {
      name: "Thames Valley District School Board",
      abbrev: "TVDSB",
      pages: ["community", "adult"],
      url: "https://calendar.tvdsb.ca/",
      debug_url: "tvdsb.html",
      finders: {
        main: {
          css: "div.calendar-list-container"
        },
        events: {
          css: "div.calendar-list-info"
        },
        link: {
          css: "a.calendar-list-title",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "a.calendar-list-title",
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '') }
        },
        datetime: {
          css: "div.calendar-list-time",
          proc: ->(x) { x.text.gsub(/^\s*/, '').gsub(/\s*$/, '').gsub(/^\S+\s+/, '').gsub(/\s+/, ' ').gsub(/-/, '@') }
        }
      }
    },
    {
      name: "London City Government Calendar",
      abbrev: "City",
      pages: ["community", "adult"],
      url: "https://london.ca/government/calendar",
      page_suffix: "?page=",
      first_page: 0,
      max_page: 10,
      debug_url: "city.html",
      debug_page_suffix: "?page=",
      finders: {
        main: {
          css: "div.view-events div.view-rows"
        },
        events: {
          css: "article.node--type-event div.teaser"
        },
        link: {
          css: "h2.teaser__title a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "h2.teaser__title a span.field--name-title",
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '') }
        },
        datetime: {
          css: "div.teaser__date time.datetime",
          proc: ->(x) { x.attribute("datetime").value }
        },
        rangesep: /DUMMY/
      }
    },
    {
      name: "Post Stanley Festival Theatre - Off Season",
      abbrev: "PSFTOff",
      pages: ["community", "adult", "culture"],
      url: "https://psft.ca/schedule/off-season-events/",
      debug_url: "psftoff.html",
      finders: {
        main: {
          css: "main.site-main"
        },
        events: {
          css: "article.psft-event"
        },
        link: {
          css: "h2.entry-title a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "h2.entry-title a",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.date-box div.date",
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ') }
        }
      }
    },
    {
      name: "Post Stanley Festival Theatre - Summer Season",
      abbrev: "PSFT",
      pages: ["community", "adult", "culture"],
      url: "https://psft.ca/schedule/summer-season/",
      debug_url: "psft.html",
      finders: {
        main: {
          css: "main.site-main"
        },
        events: {
          css: "article.psft-event"
        },
        link: {
          css: "h2.entry-title a",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "h2.entry-title a",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.date-box div.date",
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ') }
        }
      }
    },
    {
      name: "Hello Maker",
      abbrev: "Maker",
      pages: ["community", "adult"],
      url: "https://www.hellomaker.ca/events",
      debug_url: "maker.html",
      finders: {
        main: {
          css: "div.eventlist"
        },
        events: {
          css: "article.eventlist-event"
        },
        link: {
          css: "a.eventlist-title-link",
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          css: "a.eventlist-title-link",
          proc: ->(x) { x.text }
        },
        date: {
          css: "div.eventlist-datetag",
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ') }
        },
        time: {
          css: "span.event-time-localized",
          proc: ->(x) {
            x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ').
              gsub(/ (\d)/, ' - \1') # if we ever use the end time then this is broken
          }
        }
      }
    },
    {
      name: "RBP Place",
      abbrev: "RBCP",
      pages: ["community", "adult"],
      url: "https://www.rbcplacelondon.com/events",
      debug_url: "rbcp.html",
      finders: {
        main: {
          css: "div.layout-content div#content div.item-list"
        },
        events: {
          css: "li div.views-field-title a"
        },
        link: {
          proc: ->(x) { x.attribute("href").value }
        },
        title: {
          proc: ->(x) { x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ').gsub(/ - .*$/, '') }
        },
        date: {
          proc: ->(x) {
            x.text.gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/\s+/, ' ').gsub(/^.* - /, '').
              gsub(/(\w+)\s+(\d+)-(\d+)/, '\1 \2 - \1 \3')
          }
        }
      }
    },
    {
      name: "Centennial Hall",
      abbrev: "Cent",
      home: "https://centennialhall.london.ca/london-event-listings.html",
      note: "Not supported: website not sufficiently structured to process"
    },
    {
      name: "100 Kellogg Lane",
      abbrev: "100K",
      home: "https://100kellogglane.com/",
      note: "Not supported: no events page"
    }
    {
      name: "Carrefour communautaire francophone de london"
      abbrev: "CCFL"
      home: "https://www.ccflondon.ca/calendrier-communautaire"
      note: "Not supported: website not sufficiently structured to process"
  ]
}
