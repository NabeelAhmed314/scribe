defmodule SocialScribe.MeetingInfoExample do
  def meeting_info_example(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      id: "82a235e2-271c-4bb6-891f-2f77704ec313",
      metadata: %{},
      meeting_url: %{meeting_id: "jqq-gusf-vvs", platform: "google_meet"},
      status_changes: [
        %{
          code: "ready",
          message: nil,
          created_at: "2025-05-24T12:04:15.203706Z",
          sub_code: nil
        },
        %{
          code: "joining_call",
          message: nil,
          created_at: "2025-05-24T23:13:01.665225Z",
          sub_code: nil
        },
        %{
          code: "in_waiting_room",
          message: nil,
          created_at: "2025-05-24T23:13:12.782221Z",
          sub_code: nil
        },
        %{
          code: "in_call_not_recording",
          message: nil,
          created_at: "2025-05-24T23:13:26.987838Z",
          sub_code: nil
        },
        %{
          code: "in_call_recording",
          message: nil,
          created_at: "2025-05-24T23:13:27.113531Z",
          sub_code: nil
        },
        %{
          code: "call_ended",
          message: nil,
          created_at: "2025-05-24T23:16:22.206023Z",
          sub_code: "call_ended_by_host"
        },
        %{
          code: "recording_done",
          message: nil,
          created_at: "2025-05-24T23:16:23.890255Z",
          sub_code: nil
        },
        %{
          code: "done",
          message: nil,
          created_at: "2025-05-24T23:16:24.319341Z",
          sub_code: nil
        }
      ],
      join_at: "2025-05-24T23:13:00Z",
      transcription_options: %{
        provider: "meeting_captions",
        use_separate_streams_when_available: false
      },
      bot_name: "Meeting Notetaker",
      video_url:
        "https://recallai-production-bot-data.s3.amazonaws.com/_workspace-74fd400e-3c9d-430f-8173-b05ec25ea595/recordings/dbdadf20-d25a-4b32-ad03-e0aa61e6df25/video_mixed/4f34e0c8-f404-4d31-9e66-9accac1862f0/bot/82a235e2-271c-4bb6-891f-2f77704ec313/AROA3Z2PRSQAET6FSC3NG%3Ai-0c3379d015d2d348d/video.mp4?AWSAccessKeyId=ASIA3Z2PRSQANJCHVON6&Signature=i3tbPmE%2BsOvWqMTbixBlBBlOYl0%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEFQaCXVzLWVhc3QtMSJHMEUCIQCAVoZwTI0z6HHWmJoDxSoKNprjaFRnMaBswm72M0Co9wIgCyXVvWERPvEgAycdGJwjldQvDqGaUUcqtK8jVzsGh7oquAUIHRAAGgw4MTEzNzg3NzUwNDAiDH3l80kcdhj7lBbNkyqVBRKq74DtmDTpz%2BFhgVJ9k%2BiKqFzF2QTMP4HA5w65mcbhm%2BNTPNN7N0%2FvdGlRatbxTGf%2BZ8spYJFtHu%2FoT3FwPJUsN8%2BXKeYjDe6AdrxTH%2BA2%2BsyZyH3czirOABvqichBjnC47WM%2Bo9fDiFYGbAwbxPn5bZrMgn4A3xGIoslsaMM%2Bu8mfLcWLvUbqqna5ARlhEu35mTjM%2F28HyPP%2B4ZwjzEs2%2BSmisTMBprVvbD5bvIEonYk9b3uQWLo5mnpT88koYV9wEC9J1KyRtGzlQVElLI%2Fv2kwKAee0wtKTttjvpT%2FC%2BathT%2F2xZhJWQ498JfljrpNWUYtD072x%2Bwc9d3a9LhN%2FWxi2EssfiIySXD1a1W74PBPdfUj5M5UMneGumt382%2Fjo%2F6uUUYXb%2FrYzZ%2FOFVD7d%2FZo%2BOT8MKsFKxIaxsEHApo9NhcU2spsTBB6PB3HBRiXCDhQj7A7MPF7BodUARuklYeaUeQyODUR6b4rSAwAvkRx6dFzhAaR5cesSz%2FVpfcmTl1q6m4nKYfrJQq1E4oUPsRCB8p9VvwB2D6e7LGWDO4zN59GRROWT9dCEMZCgleRZ0PYMhu6qQVv4IwB3m8b2sVDhMIjVe745H1dZ4GXfEV2MC37uFr%2FnPO%2F2gRPNxH%2Fq0DsAK9N4ABBaEt%2FXiCq8OXbA4nHSgO6sdpdhHW5ifvlvgLrLNTfgEK6u0HIXpDnhmq%2BrGNGIaZCXunJQu1ZLhP%2FJWKTSki2JNlZgBOT52vgN0SEGkOe0gDUpswmw%2FfT4bpIVNtFHOi5KsAcP68294AFxQw4z2brGEiJjH0e9SFEJr%2FttUGypoOoUj22YvSsl5WuRZSNX6J4M88YSiUC8UrekYxF5zqONZ6zx4AoeIYT%2FN2Qw68vIwQY6sQGy8PfPjr8vAuGRrH5Se8NJU5c%2FQJCJIQUqtn1JUslL6vKxLGZpRDcNcoCjwXtDZ8T%2BrCZFTnFgqlbGWk6Z9zk7FDeJl%2BwrX%2B9K6Pr%2Fp72iVMM8thZIdf4vKJL59AvfVS5DkaoqoISaxMjcbsmBbXp8p60d68ukYMWZJqcMQ2iQitxr8rcDHjq1PGPcJCI8e8DNpmUdH85nB1BAx5hYfSOMW3nAsVBwRT%2Fy08C2Zd1c4Qg%3D&Expires=1748150394",
      media_retention_end: "2025-05-31T23:16:23.890255Z",
      meeting_metadata: %{title: "jqq-gusf-vvs"},
      meeting_participants: [
        %{
          id: 100,
          name: "Felipe Gomes Paradas",
          events: [%{code: "join", created_at: "2025-05-24T23:13:27.434000Z"}],
          is_host: true,
          platform: "unknown",
          extra_data: nil
        }
      ],
      recording_mode: "speaker_view",
      recordings: [
        %{
          id: "dbdadf20-d25a-4b32-ad03-e0aa61e6df25",
          started_at: "2025-05-24T23:13:27.113531Z",
          created_at: "2025-05-24T23:13:27.113531Z",
          completed_at: "2025-05-24T23:16:23.890255Z"
        }
      ],
      automatic_leave: %{
        waiting_room_timeout: 1200,
        noone_joined_timeout: 1200,
        everyone_left_timeout: 2,
        in_call_not_recording_timeout: 3600,
        recording_permission_denied_timeout: 30,
        silence_detection: %{timeout: 3600, activate_after: 1200},
        bot_detection: %{
          using_participant_events: %{timeout: 600, activate_after: 1200}
        }
      },
      calendar_meetings: [],
      recording: "dbdadf20-d25a-4b32-ad03-e0aa61e6df25"
    })
  end
end
