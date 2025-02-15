import birl
import gleam/bool
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import plinth/javascript/storage

// import lustre/ui

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let store = case storage.local() {
    Ok(s) -> s
    Error(_) -> {
      io.println_error("Failed to get local storage")
      panic
    }
  }
  let app = lustre.simple(init, update, view(_, store))
  let assert Ok(_) = lustre.start(app, "#app", #(store, 0))

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    pad: Int,
    naam: Option(String),
    datum_gemaild: Option(String),
    antwoord_opties: List(#(String, Int)),
    huidig_script: String,
    emailadresgebruikt: Option(String),
    schoolnaam: Option(String),
    ballon: Bool,
    notes_open: Bool,
    notes_value: String,
  )
}

fn encode_model(model: Model) -> json.Json {
  json.object([
    #("pad", json.int(model.pad)),
    #("naam", case model.naam {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("datum_gemaild", case model.datum_gemaild {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #(
      "antwoord_opties",
      json.array(model.antwoord_opties, fn(value) {
        json.preprocessed_array([json.string(value.0), json.int(value.1)])
      }),
    ),
    #("huidig_script", json.string(model.huidig_script)),
    #("emailadresgebruikt", case model.emailadresgebruikt {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("schoolnaam", case model.schoolnaam {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("ballon", json.bool(model.ballon)),
    #("notes_open", json.bool(model.notes_open)),
    #("notes_value", json.string(model.notes_value)),
  ])
}

fn model_decoder() -> decode.Decoder(Model) {
  use pad <- decode.field("pad", decode.int)
  use naam <- decode.field("naam", decode.optional(decode.string))
  use datum_gemaild <- decode.field(
    "datum_gemaild",
    decode.optional(decode.string),
  )
  use antwoord_opties <- decode.field(
    "antwoord_opties",
    decode.list({
      use a <- decode.field(0, decode.string)
      use b <- decode.field(1, decode.int)

      decode.success(#(a, b))
    }),
  )
  use huidig_script <- decode.field("huidig_script", decode.string)
  use emailadresgebruikt <- decode.field(
    "emailadresgebruikt",
    decode.optional(decode.string),
  )
  use schoolnaam <- decode.field("schoolnaam", decode.optional(decode.string))
  use ballon <- decode.field("ballon", decode.bool)
  use notes_open <- decode.field("notes_open", decode.bool)
  use notes_value <- decode.field("notes_value", decode.string)
  decode.success(Model(
    pad:,
    naam:,
    datum_gemaild:,
    antwoord_opties:,
    huidig_script:,
    emailadresgebruikt:,
    schoolnaam:,
    ballon:,
    notes_open:,
    notes_value:,
  ))
}

const clean_model = Model(
  pad: -1,
  antwoord_opties: [],
  naam: None,
  datum_gemaild: None,
  huidig_script: "",
  emailadresgebruikt: None,
  schoolnaam: Some("het Koning Willem I College"),
  ballon: True,
  notes_open: False,
  notes_value: "",
)

// INIT ------------------------------------------------------------------------
fn init(vars: #(storage.Storage, Int)) -> Model {
  case vars.1 {
    1 -> {
      // Debugging mode
      Model(
        pad: -1,
        naam: Some(willekeurige_naam()),
        datum_gemaild: Some("2025-02-10"),
        antwoord_opties: [],
        huidig_script: "",
        emailadresgebruikt: Some("Jouwemail@gmail.com"),
        schoolnaam: Some("het Koning Willem I College"),
        ballon: True,
        notes_open: True,
        notes_value: "",
      )
    }
    _ -> {
      let saved = storage.get_item(vars.0, "last_model")
      case saved {
        Ok(saved) -> {
          let a = json.parse(saved, model_decoder())
          case a {
            Ok(a) -> a
            Error(_) -> clean_model
          }
        }
        Error(_) -> clean_model
      }
    }
  }
}

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  AnswerredMsg(Int)
  NameFilledInMsg(String)
  DateFilledInMsg(String)
  SchoolFilledInMsg(String)
  EmailAdressFilledInMsg(String)
  GebruikerResetMsg
  NoteToggleMsg
  NoteCloseMsg
  NoteEditMsg(String)
}

fn update(model: Model, msg: Msg) -> Model {
  let uh_oh =
    Model(
      ..model,
      huidig_script: "Er is geen vervolg voor deze keuze, uh-oh.",
      antwoord_opties: [],
      ballon: False,
    )
  case msg {
    NameFilledInMsg(naam) -> Model(..model, naam: Some(naam))
    DateFilledInMsg(datum_gemaild) ->
      Model(..model, datum_gemaild: Some(datum_gemaild))
    GebruikerResetMsg -> clean_model
    AnswerredMsg(answer) ->
      case model.pad, answer {
        -1, _ -> {
          let moment_van_mailen =
            model.datum_gemaild
            |> option.unwrap(datum_vandaag())
            |> datum_terug_op_volgorde()
            |> birl.from_naive()
            |> result.unwrap(birl.now())
            |> datum_als_gesproken()
          let te_zeggen =
            begroeting()
            <> ". U spreekt met "
            <> model.naam |> option.unwrap("[naam]")
            <> ". Ik ben student op "
            <> model.schoolnaam |> option.unwrap("[schoolnaam]")
            <> " en heb uw bedrijf "
            <> moment_van_mailen
            <> " per email benaderd. Kunt u mij vertellen of deze email is ontvangen?"

          let antwoorden_daarop = [
            #("Ja", 1),
            #("Nee", 2),
            #("Weet ik niet", 3),
          ]
          Model(
            ..model,
            pad: 0,
            huidig_script: te_zeggen,
            antwoord_opties: antwoorden_daarop,
          )
        }
        0, a -> {
          case a {
            // Ja
            1 ->
              Model(
                ..model,
                huidig_script: "Ik heb geen reactie ontvangen. Kunt u mij vertellen wat de status is?",
                antwoord_opties: [
                  #("Wij hebben geen stageplaatsen", 1),
                  #("Er wordt nog naar gekeken", 2),
                ],
                pad: 1,
              )
            _ -> uh_oh
          }
        }
        _, _ -> uh_oh
      }
    EmailAdressFilledInMsg(mail) ->
      Model(..model, emailadresgebruikt: Some(mail))
    SchoolFilledInMsg(schoolname) ->
      Model(..model, schoolnaam: Some(schoolname))
    NoteEditMsg(new) -> Model(..model, notes_value: new)
    NoteToggleMsg ->
      Model(..model, notes_open: model.notes_open |> bool.negate())
    NoteCloseMsg -> Model(..model, notes_open: False)
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model, store: storage.Storage) -> Element(Msg) {
  encode_model(model)
  |> json.to_string()
  |> storage.set_item(store, "last_model", _)
  |> result.unwrap(Nil)
  case model.pad {
    -1 -> view_start(model)
    _ ->
      html.main(
        [
          attribute.class(
            "self-center m-l-auto m-r-auto w-3/4 md:w-fit ring-offset-rose-950 text-base",
          ),
        ],
        [
          view_notepad(model),
          html.span(
            // floating button to reset the form
            [
              attribute.class(
                "absolute top-2 right-2 h-[6vh] w-[6vh] m-2 btn btn-circle btn-sm  btn-warning fa-solid fa-rotate-left text-lg",
              ),
              event.on_click(GebruikerResetMsg),
            ],
            [],
          ),
          case model.ballon {
            True -> {
              html.div([attribute.class("chat-end chat")], [
                html.div([attribute.class("chat-bubble")], [
                  element.text(model.huidig_script),
                ]),
              ])
            }
            False ->
              html.div([attribute.class("")], [
                element.text(model.huidig_script),
              ])
          },
          html.div([attribute.class("chat-start chat")], [
            html.div(
              case model.antwoord_opties {
                [] -> []
                _ -> [attribute.class(" chat-bubble")]
              },
              [
                html.div(
                  [
                    attribute.class(
                      "join join-horizontal gap-1 overflow-x-scroll",
                    ),
                  ],
                  {
                    model.antwoord_opties
                    |> list.map(fn(optie) {
                      html.button(
                        [
                          event.on_click(AnswerredMsg(optie.1)),
                          attribute.class("join-item btn btn-xs rounded-lg"),
                        ],
                        [element.text(optie.0)],
                      )
                    })
                  },
                ),
              ],
            ),
          ]),
        ],
      )
  }
}

fn view_start(model: Model) {
  html.main(
    [
      attribute.class(
        "self-center m-l-auto m-r-auto w-3/4 md:w-fit ring-offset-rose-950 text-base",
      ),
    ],
    [
      view_notepad(model),
      html.div([attribute.class("join join-vertical gap-2")], [
        html.label([attribute.class("join-item"), attribute.for("naam")], [
          element.text("Je naam?"),
          html.input([
            attribute.placeholder(willekeurige_naam()),
            attribute.id("naam"),
            attribute.class("w-full input input-bordered"),
            attribute.type_("name"),
            attribute.value({ model.naam |> option.unwrap("") }),
            event.on_input(fn(a) {
              a |> io.debug()
              NameFilledInMsg("")
            }),
          ]),
        ]),
        html.label(
          [attribute.class("join-item"), attribute.for("datum_gemaild")],
          [
            element.text("Wanneer heb je dit bedrijf gemaild?"),
            html.input([
              attribute.id("datum_gemaild"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("date"),
              attribute.placeholder(datum_vandaag()),
              attribute.value({ model.datum_gemaild |> option.unwrap("") }),
              event.on_input(DateFilledInMsg),
            ]),
          ],
        ),
        html.label(
          [attribute.class("join-item"), attribute.for("mail_gebruikt")],
          [
            element.text("Met welk adres heb je gemaild?"),
            html.input([
              attribute.id("mail_gebruikt"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("mail"),
              attribute.placeholder("jij@jouwschool-edu.nl"),
              attribute.value({ model.emailadresgebruikt |> option.unwrap("") }),
              event.on_input(EmailAdressFilledInMsg),
            ]),
          ],
        ),
        html.label(
          [attribute.class("join-item"), attribute.for("mail_gebruikt")],
          [
            element.text("Op welke school zit je?"),
            html.input([
              attribute.id("mail_gebruikt"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("text"),
              attribute.value({
                model.schoolnaam |> option.unwrap("het Koning Willem I College")
              }),
              event.on_input(EmailAdressFilledInMsg),
            ]),
          ],
        ),
        html.button(
          [
            attribute.class("w-full btn btn-bordered"),
            event.on_click(GebruikerResetMsg),
          ],
          [element.text("Reset")],
        ),
        html.button(
          {
            case
              model.datum_gemaild,
              model.naam,
              model.emailadresgebruikt,
              model.schoolnaam
            {
              Some(_), Some(_), Some(_), Some(_) -> [
                // Formulier is ingevuld, laat gebruiker starten
                attribute.class(
                  "w-full btn btn-bordered btn-outline btn-success",
                ),
                event.on_click(AnswerredMsg(0)),
              ]
              _, _, _, _ -> [
                // Formulier is niet ingevuld, laat gebruiker niet starten
                attribute.class("w-full btn btn-disabled btn-ghost"),
                attribute.disabled(True),
              ]
            }
          },
          [element.text("Start met bellen")],
        ),
      ]),
    ],
  )
}

// Left floating is a big notepad
fn view_notepad(model: Model) {
  html.section(
    [
      attribute.class("absolute top-2 left-2 w-fit"),
      event.on_mouse_leave(NoteCloseMsg),
    ],
    [
      html.span(
        [
          attribute.class(
            "h-[6vh] w-[6vh] m-2 btn btn-circle btn-xs  btn-warning fa-solid fa-sticky-note text-lg z-[100] ",
          ),
          event.on_click(NoteToggleMsg),
        ],
        [],
      ),
    ]
      |> list.append(case model.notes_open {
        True -> [
          html.div(
            [
              attribute.class(
                " top-[12vh] left-0 w-[90vw] h-[80VH] m-0 md:w-[40VW] bg-white p-2",
              ),
            ],
            [
              html.textarea(
                [
                  attribute.style([#("word-break", "break-word")]),
                  attribute.class(
                    "w-full h-full input bg-accent text-accent-content input-bordered",
                  ),
                  attribute.value(model.notes_value),
                  event.on_input(NoteEditMsg),
                ],
                "",
              ),
            ],
          ),
        ]
        False -> []
      }),
  )
}

// Time-based personalisation functions -------------------------------------------------------
fn begroeting() {
  let birl.TimeOfDay(uur_van_de_dag, _, _, _) = birl.get_time_of_day(birl.now())
  case uur_van_de_dag {
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 -> "Goedemorgen"
    12 | 13 | 14 | 15 | 16 | 17 -> "Goedemiddag"
    18 | 19 | 20 | 21 | 22 | 23 -> "Goedenavond"
    _ -> "Hallo"
  }
}

fn afscheid() {
  case birl.now() |> birl.weekday() {
    birl.Mon | birl.Tue | birl.Wed | birl.Thu -> "Fijne dag"
    birl.Fri -> "Fijn weekend"
    _ -> "Fijne rest van uw weekend"
  }
}

fn datum_vandaag() {
  let wrong = birl.now() |> birl.to_naive_date_string()
  // this creates a "YYYY-MM-DD" string
  // we need to split it into parts and reformat it to "DD-MM-YYYY"
  let splitted = wrong |> string.split("-")
  let year = splitted |> list.first() |> result.unwrap("2025")
  let splitted = splitted |> list.rest() |> result.unwrap(["02", "15"])
  let month = splitted |> list.first() |> result.unwrap("02")
  let splitted = splitted |> list.rest() |> result.unwrap(["15"])
  let day = splitted |> list.last() |> result.unwrap("15")
  day <> "-" <> month <> "-" <> year
}

fn datum_terug_op_volgorde(datum: String) {
  let splitted = datum |> string.split("-") |> list.reverse()
  case
    splitted |> list.first() |> result.unwrap("2025-02-15") |> string.length()
  {
    4 -> splitted |> string.join("-")
    _ -> datum
  }
}

fn datum_als_gesproken(datum: birl.Time) {
  let uren_sinds_datum =
    { birl.to_unix(birl.now()) - birl.to_unix(datum) } / 3600
  let dow = birl.weekday(datum)
  case uren_sinds_datum {
    j if j < 24 -> "vandaag"
    j if j < 48 -> "gisteren"
    j if j < 50 -> "eergisteren"
    _ ->
      case uren_sinds_datum / 24 {
        1 -> "gisteren"
        2 -> "eergisteren"
        3 -> "3 dagen geleden"
        dagen_sinds_datum ->
          case dagen_sinds_datum < 8 {
            True ->
              "afgelopen "
              <> case dow {
                birl.Mon -> "maandag"
                birl.Tue -> "dinsdag"
                birl.Wed -> "woensdag"
                birl.Thu -> "donderdag"
                birl.Fri -> "vrijdag"
                birl.Sat -> "zaterdag"
                birl.Sun -> "zondag"
              }
            False -> "op " <> datum |> birl.to_naive_date_string()
          }
      }
  }
}

// Miscelaneous functions ---------------------------------------------------------------------

fn willekeurige_naam() {
  [
    "Bert Pieters", "Jan Jansen", "Piet de Boer", "Karin van der Pol",
    "Jan van der Pol", "Anneke Pieters", "Johanna de Vries", "Jannie Jansen",
    "Henriette de Vries", "Klaartje Jansen", "Karin de Boer", "Jane Doe",
    "Alice Johnson", "Bob Brown", "Charlie White", "David Black",
    "Aisha Ten-Bosch", "Paula Stevens", "Liam Smith", "Olivia Johnson",
    "Noah Williams", "Emma Brown", "Oliver Jones", "Ava Garcia",
    "Elijah Martinez", "Sophia Rodriguez", "Lucas Hernandez", "Isabella Lopez",
    "Mason Gonzalez", "Mia Wilson", "Ethan Anderson", "Amelia Thomas",
    "James Taylor", "Harper Moore", "Benjamin Jackson", "Evelyn Martin",
    "Alexander Lee", "Abigail Perez", "Henry Thompson", "Emily White",
    "Sebastian Harris", "Elizabeth Sanchez", "Jack Clark", "Sofia Ramirez",
    "Owen Lewis", "Avery Robinson", "Samuel Walker", "Ella Young",
    "Matthew Allen", "Scarlett King", "Joseph Wright", "Grace Scott",
    "Levi Green", "Chloe Adams", "Mateo Baker", "Victoria Nelson", "David Hill",
    "Riley Carter", "John Rivera", "Aria Mitchell", "Wyatt Roberts",
    "Lily Turner", "Carter Phillips", "Aubrey Campbell", "Julian Parker",
    "Zoey Evans", "Grayson Edwards", "Kai Nakamura", "Zara Patel",
    "Finn O'Malley", "Luna Kowalski", "Nico Rossi", "Freya Müller",
    "Soren Larsen", "Anika Gupta", "Rafael Silva", "Yara Haddad",
    "Dante Moretti", "Ines Fernandez", "Kian Novak", "Leila Chen", "Milo Petrov",
    "Saskia van Dijk", "Arjun Singh", "Elara Volkov", "Tariq Al-Farsi",
    "Nina Yamamoto", "Bodhi Nguyen", "Zaina Rahman", "Elias Svensson",
    "Mira Kuznetsov", "Orion Varga", "Ayla Demir", "Rohan Mehta",
    "Sienna Laurent", "Koa Tanaka", "Liora Cohen", "Thiago Costa",
    "Amara Okafor", "Zane Malik", "Soraya Bakker", "Eamon Gallagher",
    "Nadia Ivanov", "Reza Karim", "Talia Abramov", "Iker Delgado",
    "Suriya Chandra", "Luka Horvat", "Mara Novak", "Jasper van Leeuwen",
    "Nia Papadopoulos", "Ravi Kapoor", "Saskia Müller", "Elior Ben-David",
    "Zofia Nowak", "Aksel Hansen", "Mina Kim",
  ]
  |> list.shuffle()
  |> list.first()
  |> result.unwrap("Bert Pieters")
}
